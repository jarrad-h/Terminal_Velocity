extends Node
## Scenario test: runs the system scene, presses flight keys and exercises every
## debug command. Run as a scene so autoloads exist:
##   godot --headless --path . res://tests/smoke/scenario.tscn

var _errors: Array[String] = []
var _debug: Node


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _run() -> void:
	_debug = DebugCommands
	var scene: Node = load("res://scenes/system.tscn").instantiate()
	get_tree().root.add_child(scene)
	await _frames(2)
	# M1–M3 checks run in an empty system; the M4 section turns traffic back on.
	_debug.set_traffic_enabled(false)
	await _frames(2)
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	_check(player != null, "player ship spawned")
	if player == null:
		_finish()
		return
	var stats: FlightStats = player.body.stats
	_check(stats.top_speed > 0.0, "flight stats loaded from data")

	Input.action_press(&"thrust")
	await _frames(240)
	Input.action_release(&"thrust")
	_check(is_equal_approx(player.get_velocity().length(), stats.top_speed), "thrust reaches the speed cap")
	_check(player.position.y < -100.0, "ship moved up the screen")

	var before: Vector2 = player.get_velocity()
	await _frames(30)
	_check(player.get_velocity().is_equal_approx(before), "ship drifts with no input")

	Input.action_press(&"reverse")
	await _frames(240)
	Input.action_release(&"reverse")
	var facing: Vector2 = FlightModel.heading(player.rotation)
	_check(facing.dot(-player.get_velocity().normalized()) > 0.999, "reverse faces against velocity")

	var camera: Camera2D = scene.get_node("Camera")
	_check(camera.global_position.distance_to(player.global_position) < 1.0, "camera follows the player")

	_debug.toggle_panel()
	for overlay: StringName in _debug.OVERLAYS:
		_debug.set_overlay(overlay, true)
	_debug.set_time_scale(10.0)
	_check(is_equal_approx(Engine.time_scale, 4.0), "time scale clamps to 4x")
	_debug.set_time_scale(0.25)
	await _frames(5)
	_debug.set_time_scale(1.0)
	_debug.set_paused(true)
	var paused_at: Vector2 = player.position
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.position == paused_at, "pause stops the ship")
	_debug.step_frame()
	await _frames(5)
	var step_delta: float = player.position.distance_to(paused_at)
	var expected: float = player.get_velocity().length() / Engine.physics_ticks_per_second
	_check(absf(step_delta - expected) < 0.01, "step advances exactly one physics frame (moved %f, expected %f)" % [step_delta, expected])
	_check(get_tree().paused, "still paused after step")
	_debug.set_paused(false)
	await _frames(5)

	# C8: the target dummy spawns in debug builds and can be selected.
	player.target_nearest(false)
	var target: Ship = player.get_target()
	_check(target != null and target.def.id == "target_dummy", "nearest target is the dummy")
	player.cycle_target(false)
	_check(player.get_target() == target, "cycling with one candidate keeps it")
	player.target_nearest(true)
	_check(player.get_target() == target, "R with no hostiles keeps the current target (C8)")

	# C1–C7: fire every weapon kind at the dummy.
	var dummy: Ship = target
	await _teleport(player, dummy.global_position + Vector2(0.0, 250.0))
	var shield_before: float = dummy.health.shield
	Input.action_press(&"fire_primary")
	await _frames(60)
	Input.action_release(&"fire_primary")
	await _frames(30)
	_check(dummy.health.shield < shield_before, "gun shots (C1/C2) hit the dummy's shield (%f -> %f)" % [shield_before, dummy.health.shield])
	_check(is_equal_approx(dummy.health.armor, dummy.health.max_armor), "shields absorb before armour (C5)")
	# C6: shields wait out the recharge delay after the last hit, then recharge.
	dummy.health.apply_damage(50.0, 0.0)
	var shield_hit: float = dummy.health.shield
	await _frames(60)
	_check(is_equal_approx(dummy.health.shield, shield_hit), "no recharge inside the delay (C6)")
	await _frames(roundi(dummy.health.recharge_delay * 60.0))
	_check(dummy.health.shield > shield_hit, "recharging after the delay (C6)")

	_debug.swap_player_ship("patrol_corvette")
	await _teleport(player, dummy.global_position + Vector2(300.0, 300.0))  # off to one side, facing up
	player.set_target(dummy)
	var before_missile: float = dummy.health.shield + dummy.health.armor
	Input.action_press(&"fire_secondary")
	await _frames(2)
	Input.action_release(&"fire_secondary")
	await _frames(150)
	_check(dummy.health.shield + dummy.health.armor < before_missile, "guided missile (C3) homes onto an off-axis target")

	_debug.swap_player_ship("pirate_raider")
	await _teleport(player, dummy.global_position + Vector2(0.0, 150.0))
	var before_beam: float = dummy.health.shield + dummy.health.armor
	Input.action_press(&"fire_primary")
	await _frames(30)
	var beam_visible: bool = player.weapons.mounts.any(func(m: WeaponMounts.Mount) -> bool: return m.beam != null and m.beam.visible)
	Input.action_release(&"fire_primary")
	await _frames(2)
	_check(beam_visible, "beam (C4) draws while held")
	_check(dummy.health.shield + dummy.health.armor < before_beam, "beam (C4) damages while held")

	dummy.health.force_disable()
	_check(dummy.health.is_disabled and not dummy.can_act(), "disabled at 33%% armour (C7)")
	dummy.health.force_destroy()
	await _frames(2)
	_check(not is_instance_valid(dummy), "destroyed dummy removed (C7)")
	# A freed object compares equal to null in Godot 4, so check validity, not == null.
	_check(not is_instance_valid(player.get_target()) and player.get_target() == null, "target cleared when destroyed (C8)")

	# Regression (M4 playtest crash): firing missiles after the target was freed
	# (destroyed or jumped out) must not pass the freed ship on.
	_debug.swap_player_ship("patrol_corvette")
	var gone: Array[Ship] = _debug.spawn_ships("pirate_raider", 1)
	await _frames(2)
	player.set_target(gone[0])
	gone[0].remove_from_group(&"ships")
	gone[0].queue_free()
	await _frames(2)
	Input.action_press(&"fire_secondary")
	Input.action_press(&"fire_primary")
	await _frames(10)
	Input.action_release(&"fire_secondary")
	Input.action_release(&"fire_primary")
	_check(player.get_target() == null and not is_instance_valid(player.get_target()), "freed target is dropped before firing")

	# L4: shots damage solid scenery; destroyed scenery stays destroyed.
	var scene_root_l4: Node = get_tree().get_first_node_in_group(&"system_scene")
	var space: LocalSpace = scene_root_l4.local_space
	var rock: Scenery = null
	for node: Node in space.find_children("*", "Scenery", true, false):
		if (node as Scenery).def.solid and (node as Scenery).def.armor >= 30.0:
			rock = node
			break
	_check(rock != null, "found solid scenery to shoot")
	if rock != null:
		var rock_chunk: Vector2i = rock.placement.chunk
		var rock_index: int = rock.placement.index
		var rock_id: String = rock.def.id
		await _teleport(player, rock.global_position + Vector2(0.0, 120.0))
		var armor_before: float = rock.health.armor
		Input.action_press(&"fire_primary")
		await _frames(20)
		Input.action_release(&"fire_primary")
		await _frames(10)
		_check(not is_instance_valid(rock) or rock.health.armor < armor_before, "shots damage solid scenery")
		if is_instance_valid(rock):
			rock.health.apply_damage(0.0, 100000.0)
		await _frames(2)
		_check(space.destroyed.has(rock_chunk, rock_id, rock_index), "destroyed scenery recorded")
		_check(space.find_children("*", "Fragment", true, false).size() > 0 or rock_id == "small_debris", "fragments spawned")
		await _teleport(player, Vector2(60000.0, 0.0))
		await _teleport(player, Vector2(rock_chunk) * space.chunk_size)
		var back: bool = false
		var holder: Node = space.chunk_node(rock_chunk)
		if holder != null:
			for node: Node in holder.get_children():
				var sc: Scenery = node
				if sc.def.id == rock_id and sc.placement.index == rock_index:
					back = true
		_check(holder != null and not back, "destroyed scenery does not come back on revisit")

	# D2: ship swap keeps position and velocity.
	var pos_before: Vector2 = player.position
	var vel_before: Vector2 = player.get_velocity()
	_check(_debug.swap_player_ship("shuttle"), "swap command succeeds")
	_check(player.def.id == "shuttle", "player is now a shuttle")
	_check(is_equal_approx(player.body.stats.top_speed, player.def.top_speed), "flight stats follow the new hull")
	_check(player.get_velocity() == vel_before and player.position == pos_before, "swap keeps position and velocity")
	_check(not _debug.swap_player_ship("no_such_ship"), "unknown ship is refused")

	# D8: reload re-reads data and live ships pick it up.
	var reload_errors: Array[String] = _debug.reload_data()
	_check(reload_errors.is_empty(), "reload succeeds: %s" % [reload_errors])
	_check(player.def.id == "shuttle" and player.def != null, "player keeps its hull after reload")

	# L1–L3: scenery streams around the camera and is the same on revisit.
	var scene_root: Node = get_tree().get_first_node_in_group(&"system_scene")
	var local_space: LocalSpace = scene_root.local_space
	await _teleport(player, Vector2.ZERO)
	_check(local_space.object_count() > 0, "scenery loaded around the player")
	var first_visit: Array[String] = _chunk_snapshot(local_space, Vector2i(0, 0))
	_check(not first_visit.is_empty(), "chunk (0,0) has scenery")
	await _teleport(player, Vector2(50000.0, 0.0))
	_check(not local_space.loaded_chunks().has(Vector2i(0, 0)), "distant chunk unloaded")
	await _teleport(player, Vector2.ZERO)
	_check(_chunk_snapshot(local_space, Vector2i(0, 0)) == first_visit, "revisited chunk holds the same objects")
	var saw_dust: bool = false
	var saw_solid: bool = false
	for node: Node in local_space.find_children("*", "Scenery", true, false):
		var scenery: Scenery = node
		var has_hitbox: bool = scenery.has_node("Hitbox") and scenery.health != null
		_check(has_hitbox == scenery.def.solid, "%s: hitbox and Health only when solid" % scenery.def.id)
		saw_dust = saw_dust or scenery.def.id == "dust"
		saw_solid = saw_solid or scenery.def.solid
	_check(saw_dust and saw_solid, "both dust and solid scenery present")

	# M4: a pirate raid on a trader draws in the patrol (A1–A3, A5, A7).
	await _teleport(player, Vector2(-5000.0, 5000.0))  # out of the way
	var traffic: TrafficSpawner = scene_root.traffic
	var centre := Vector2(2500.0, -2500.0)
	var trader: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("trader_traffic"), centre, "", "steady")
	var pirate: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("pirate_raid"), centre + Vector2(500.0, 0.0), "", "steady")
	await _frames(90)
	var pirate_ai: AIController = pirate.controller
	_check(pirate_ai.state == AIController.State.ATTACK and pirate_ai.target == trader, "pirate attacks the trader on sight (A3): %s" % pirate.get_state_label())
	await _frames(240)
	var trader_ai: AIController = trader.controller
	_check(not is_instance_valid(trader) or trader_ai.state == AIController.State.FLEE or trader.health.shield < trader.health.max_shield,
		"trader under attack (A1): %s" % (trader.get_state_label() if is_instance_valid(trader) else "gone"))
	if is_instance_valid(trader):
		_check(trader_ai.state == AIController.State.FLEE, "steady trader flees when attacked (A1): %s" % trader.get_state_label())
	var patrol: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("authority_patrol"), pirate.global_position + Vector2(0.0, 900.0), "", "steady")
	await _frames(90)
	var patrol_ai: AIController = patrol.controller
	_check(is_instance_valid(pirate) and patrol_ai.state == AIController.State.ATTACK and patrol_ai.target == pirate,
		"patrol is drawn in against the pirate (A2): %s" % patrol.get_state_label())
	var trader_label: String = trader.get_state_label() if is_instance_valid(trader) else ""
	_check(trader_label == "" or trader_label.begins_with("trader/steady"), "label shows role and personality (A7): %s" % trader_label)

	# A8 + G2: accidental hits are forgiven; sustained fire turns that ship hostile and costs record once.
	var victim: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("trader_traffic"), Vector2(-4600.0, 5000.0), "", "brave")
	await _frames(2)
	var record_before: float = GameState.get_record("independent_traders")
	victim.health.apply_damage(1.0, 1.0, player)
	victim.health.apply_damage(1.0, 1.0, player)
	_check(victim.grievance > 0.0 and not victim.is_hostile_to(player), "a couple of stray hits are forgiven (A8)")
	_check(is_equal_approx(GameState.get_record("independent_traders"), record_before), "no record penalty for forgiven hits (G2)")
	await _frames(30)
	_check((victim.controller as AIController).state != AIController.State.ATTACK, "forgiven: the brave trader doesn't fight back")
	var total: float = victim.health.max_shield + victim.health.max_armor
	victim.health.apply_damage(total * 0.4, total * 0.4, player)
	var shoot_penalty: float = DataRegistry.get_government("independent_traders").penalties["shoot"]
	_check(victim.is_hostile_to(player) and player.is_hostile_to(victim), "sustained fire passes tolerance: hostile (A8)")
	_check(is_equal_approx(GameState.get_record("independent_traders"), record_before - shoot_penalty), "attack penalty charged once, at the tolerance (G2)")
	victim.health.apply_damage(1.0, 1.0, player)
	_check(is_equal_approx(GameState.get_record("independent_traders"), record_before - shoot_penalty), "and only once")
	await _frames(30)
	if is_instance_valid(victim) and victim.can_act():
		var reaction: AIController.State = (victim.controller as AIController).state
		# Brave traders fight back (A7) unless the hit also took them under their flee threshold (A4).
		_check(reaction == AIController.State.ATTACK or reaction == AIController.State.FLEE, "the trader reacts once hostile: %s" % victim.get_state_label())

	# G3: below the crime threshold, warships turn hostile.
	var law_patrol: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("authority_patrol"), Vector2(-3000.0, 3000.0), "", "steady")
	await _frames(2)
	_check(not law_patrol.is_hostile_to(player), "patrol neutral at record 0")
	var threshold: float = DataRegistry.get_government("local_authority").crime_threshold
	GameState.set_record("local_authority", threshold - 1.0)
	_check(law_patrol.is_hostile_to(player), "patrol hostile below the crime threshold (G3)")
	GameState.set_record("local_authority", 0.0)
	_check(not law_patrol.is_hostile_to(player), "neutral again above it")
	# A8: one ship's grievance doesn't turn the rest of its government.
	var other_patrol: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("authority_patrol"), Vector2(3000.0, 3000.0), "", "steady")
	await _frames(2)
	var patrol_total: float = law_patrol.health.max_shield + law_patrol.health.max_armor
	law_patrol.health.apply_damage(patrol_total * 0.4, patrol_total * 0.4, player)
	_check(law_patrol.is_hostile_to(player), "the patrol ship you attacked is hostile (A8)")
	_check(not other_patrol.is_hostile_to(player), "other ships of its government stay neutral (A8)")

	# C11: AI shots on allies scale by combat.friendly_fire_pct.
	var pct: float = float(DataRegistry.settings["combat"]["friendly_fire_pct"])
	_check(is_equal_approx(HitQuery.damage_scale_from(law_patrol, victim), pct / 100.0), "AI on ally: friendly_fire_pct (C11)")
	_check(is_equal_approx(HitQuery.damage_scale_from(player, law_patrol), 1.0), "player always full damage (C11)")

	# D4: AI pause.
	_debug.set_ai_paused(true)
	await _frames(3)
	var paused_input: FlightInput = other_patrol.get_flight_input()
	_check(not paused_input.thrust and paused_input.turn == 0.0 and not paused_input.fire_primary, "AI paused gives no input (D4)")
	_debug.set_ai_paused(false)
	# D3: spawn a pool with a government override; D6: credits and record.
	var raid: Array[Ship] = _debug.spawn_pool("pirate_raid", 2, "local_authority")
	_check(raid.size() == 2 and raid.all(func(sh: Ship) -> bool: return sh.government == "local_authority" and sh.controller is AIController),
		"spawn pool with government override (D3)")
	var placed: Array[Ship] = _debug.spawn_pool("trader_traffic", 1, "", Vector2(1234.0, -987.0))
	_check(placed.size() == 1 and placed[0].global_position.distance_to(Vector2(1234.0, -987.0)) < 1.0, "spawn at a position (D3 cursor)")
	_debug.set_credits(1234)
	_check(GameState.credits == 1234, "set credits (D6)")
	_debug.set_record("pirates", 1500.0)
	_check(GameState.get_record("pirates") == 1500.0, "set record (D6)")
	_debug.set_record("pirates", 0.0)
	_debug.clear_ships()
	await _frames(2)

	# D8 regression (M4 soak): a data reload keeps damage and the disabled state,
	# so disabled traffic isn't revived and counted again.
	var wreck: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("pirate_raid"), Vector2(-3500.0, -3500.0), "", "steady")
	var hurt: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("pirate_raid"), Vector2(3500.0, -3500.0), "", "steady")
	await _frames(2)
	wreck.health.force_disable()
	hurt.health.apply_damage(hurt.health.max_shield, 0.0)
	var hurt_shield: float = hurt.health.shield
	_debug.reload_data()
	await _frames(2)
	_check(wreck.health.is_disabled, "reload keeps a disabled ship disabled (D8)")
	_check(is_equal_approx(hurt.health.shield, hurt_shield), "reload doesn't heal (D8)")
	_debug.clear_ships()
	await _frames(2)

	# A6: traffic refills the system to its target counts.
	_debug.set_traffic_enabled(true)
	await _frames(2)
	var target_total: int = 0
	for t: Dictionary in scene_root.system.traffic:
		target_total += t["count"]
	_check(traffic.live_count() == target_total, "traffic fills to the target population (A6): %d of %d" % [traffic.live_count(), target_total])
	_debug.set_traffic_enabled(false)
	await _frames(2)

	# System switch.
	_check(_debug.switch_system("test_graveyard"), "switch to test_graveyard")
	_check(_debug.current_system_id() == "test_graveyard", "current system updated")
	await _teleport(player, Vector2(2200.0, 0.0))
	var hulls: int = 0
	for node: Node in local_space.find_children("*", "Scenery", true, false):
		if (node as Scenery).def.id == "derelict_hull":
			hulls += 1
	_check(hulls > 0, "graveyard ring has derelict hulls")
	var radar_list: Array[Scenery] = local_space.radar_objects()
	_check(radar_list.size() > 0 and radar_list.all(func(sc: Scenery) -> bool: return sc.def.radar), "radar lists only radar: true scenery (H2)")
	var hud: Hud = scene_root.hud
	_check(hud.radar != null and hud.radar.player == player, "radar follows the player (H2)")
	_check(not _debug.switch_system("nowhere"), "unknown system is refused")
	_check(local_space.destroyed.size() == 0, "destroyed set cleared on system change")
	# D3–D5, D9
	var spawned: Array[Ship] = _debug.spawn_ships("pirate_raider", 3, "pirates")
	_check(spawned.size() == 3 and spawned.all(func(sh: Ship) -> bool: return sh.government == "pirates"), "spawn 3 ships with a government (D3)")
	await _frames(2)
	player.set_target(spawned[0])
	_check(_debug.disable_target() and spawned[0].health.is_disabled, "disable target (D5)")
	_check(_debug.destroy_target(), "destroy target (D5)")
	await _frames(2)
	_check(not is_instance_valid(spawned[0]), "destroyed target removed")
	_debug.set_player_invulnerable(true)
	var armor_now: float = player.health.armor
	player.health.apply_damage(1000.0, 1000.0)
	_check(player.health.armor == armor_now, "invulnerable player takes no damage (D4)")
	_debug.set_player_invulnerable(false)
	_check(_debug.clear_ships() == 2, "clear removes the remaining spawned ships (D5)")
	await _frames(2)
	_check(get_tree().get_nodes_in_group(&"ships").size() == 1, "only the player is left")
	_check(_debug.player_location_text().contains("Chunk ("), "position and chunk readout (D9)")
	await _frames(5)
	_finish()


func _teleport(ship: Ship, at: Vector2) -> void:
	ship.body.state = FlightState.new(at, Vector2.ZERO, 0.0)
	await _frames(3)


func _chunk_snapshot(local_space: LocalSpace, chunk: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var holder: Node = local_space.chunk_node(chunk)
	if holder == null:
		return out
	for node: Node in holder.get_children():
		var scenery: Scenery = node
		out.append("%s %s %.3f" % [scenery.def.id, scenery.placement.position.round(), scenery.placement.size])
	out.sort()
	return out


func _finish() -> void:
	for e: String in _errors:
		print("FAIL ", e)
	print("scenario: %d failures" % _errors.size())
	get_tree().quit(1 if _errors.size() > 0 else 0)
