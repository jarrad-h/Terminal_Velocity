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
	var hud: Hud = get_tree().get_first_node_in_group(&"system_scene").hud
	await _frames(2)
	_check(hud.target_panel.visible and hud.target_panel._class.text == "Target Dummy" and hud.target_panel._standing.text == "Neutral",
		"target panel shows class and standing (H3, G5): %s / %s" % [hud.target_panel._class.text, hud.target_panel._standing.text])
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

	# M6: ship art, hull capsule, turret and pivot mounts (V1–V5).
	_check(player.def.id == "shuttle", "player starts in the shuttle (M6)")
	var capsule: CapsuleShape2D = player.hitbox_shape.shape as CapsuleShape2D
	_check(capsule != null and is_equal_approx(capsule.height, player.def.hit_size.y * player.art_scale), "capsule hitbox from hit_size (V2)")
	_check(player.visual.get_node_or_null(^"EngineGlow") != null and player.visual.get_child_count() == 2, "sprite plus engine glow (V1, V5)")
	await _teleport(player, dummy.global_position + Vector2(300.0, 0.0))  # dummy abeam to port, ship facing up
	player.set_target(dummy)
	await _frames(30)
	var turret: WeaponMounts.Mount = player.weapons.mounts[0]
	_check(turret.mount == "turret" and absf(angle_difference(turret.angle, -PI / 2.0)) < 0.1,
		"turret swings onto a target abeam (V4): %.1f°" % rad_to_deg(turret.angle))
	_check(turret.barrel.get_node_or_null(^"TurretSprite") != null and is_equal_approx(turret.barrel.rotation, turret.angle), "turret sprite turns with the barrel (V4)")
	var abeam_before: float = dummy.health.shield + dummy.health.armor
	Input.action_press(&"fire_primary")
	await _frames(40)
	Input.action_release(&"fire_primary")
	await _frames(30)
	_check(dummy.health.shield + dummy.health.armor < abeam_before, "turret hits a target the ship isn't facing (C2)")
	var setup_errors: Array[String] = []
	var pivot_def: ShipDef = ShipDef.parse(DefReader.new({"name": "Pivot test", "accel": 1, "top_speed": 1, "turn_rate": 1,
		"hardpoints": [{"id": "P1", "size": "small", "mount": "pivot", "pos": [0, -20]}],
		"loadout": [{"hardpoint": "P1", "weapon": "laser_small", "mount": "pivot"}]}, "scenario", setup_errors))
	player.setup(pivot_def)
	await _frames(30)
	var pivot: WeaponMounts.Mount = player.weapons.mounts[0]
	_check(setup_errors.is_empty() and absf(absf(pivot.angle) - deg_to_rad(15.0)) < 0.01, "pivot held at its ±15° edge (V3): %.1f°" % rad_to_deg(pivot.angle))
	var shots: Node = get_tree().get_first_node_in_group(&"shots")
	var shots_before: int = shots.get_child_count()
	Input.action_press(&"fire_primary")
	await _frames(2)
	Input.action_release(&"fire_primary")
	_check(shots.get_child_count() > shots_before, "pivot keeps firing with the target outside its arc (V3)")
	# The pivot sits 20 px ahead of the centre: put the dummy 10° to port of it.
	await _teleport(player, dummy.global_position + Vector2(280.0 * tan(deg_to_rad(10.0)), 300.0))
	await _frames(30)
	_check(absf(absf(pivot.angle) - deg_to_rad(10.0)) < 0.03, "pivot tracks a target 10° off the nose (V3): %.1f°" % rad_to_deg(pivot.angle))

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
	var trader_ai: AIController = trader.controller
	await _frames(240)
	# Ships are delicate (M7): the trader may already be disabled or gone.
	_check(not is_instance_valid(trader) or trader.health.is_disabled or trader_ai.state == AIController.State.FLEE or trader.health.shield < trader.health.max_shield,
		"trader under attack (A1): %s" % (trader.get_state_label() if is_instance_valid(trader) else "gone"))
	if is_instance_valid(trader) and not trader.health.is_disabled:
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
	_check(victim.standing_to(player) == "angry", "grievance shows as angry (G5)")
	_check(is_equal_approx(GameState.get_record("independent_traders"), record_before), "no record penalty for forgiven hits (G2)")
	await _frames(30)
	_check((victim.controller as AIController).state != AIController.State.ATTACK, "forgiven: the brave trader doesn't fight back")
	var total: float = victim.health.max_shield + victim.health.max_armor
	victim.health.apply_damage(total * 0.4, total * 0.4, player)
	var shoot_penalty: float = DataRegistry.get_government("independent_traders").penalties["shoot"]
	_check(victim.is_hostile_to(player) and player.is_hostile_to(victim), "sustained fire passes tolerance: hostile (A8)")
	_check(victim.standing_to(player) == "hostile", "standing hostile (G5)")
	_check(hud.messages.latest().contains("turns hostile") and hud.messages.latest_kind() == "standing", "turns-hostile message (H4): %s" % hud.messages.latest())
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
	_check(hud.messages.latest().contains("now treats you as hostile"), "threshold message (H4, G3): %s" % hud.messages.latest())
	GameState.set_record("local_authority", 0.0)
	_check(not law_patrol.is_hostile_to(player), "neutral again above it")
	_check(hud.messages.latest().contains("no longer treats you as hostile"), "threshold message on the way back (H4)")
	var friendly_at: float = DataRegistry.get_government("local_authority").friendly_record
	GameState.set_record("local_authority", friendly_at)
	_check(law_patrol.standing_to(player) == "friendly", "friendly at friendly_record (G5)")
	GameState.set_record("local_authority", 0.0)
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

	# M5: landing (S2, G4, S3) and the message line (H4).
	var actions: PlayerActions = scene_root.actions
	var haven: SystemObjectDef = null
	for obj: SystemObjectDef in scene_root.system.objects:
		if obj.id == "haven":
			haven = obj
	await _teleport(player, haven.position + Vector2(haven.radius * 3.0, 0.0))
	_check(actions.try_land() == "far", "too far to land gives a hint (S2)")
	_check(scene_root.hud.messages.latest().begins_with("Too far"), "hint on the message line (H4): %s" % scene_root.hud.messages.latest())
	player.place(haven.position, 0.0, Vector2(200.0, 0.0))
	_check(actions.try_land() == "fast", "too fast to land (S2)")
	GameState.set_record("local_authority", haven.min_record - 1.0)
	player.place(haven.position, 0.0)
	_check(actions.try_land() == "refused", "refused below min_record (G4)")
	GameState.set_record("local_authority", 0.0)
	player.health.apply_damage(50.0, 30.0)
	var day_before_landing: int = GameState.clock.day
	GameState.travel.fuel = 50.0
	GameState.set_credits(1000)
	_check(actions.try_land() == "", "lands when close, slow and welcome (S2)")
	_check(GameState.clock.day == day_before_landing + haven.landing_days, "TM2: landing costs its days")
	_check(get_tree().paused and actions.dialog != null, "landed screen open, world paused (S3)")
	_check(actions.dialog.has_choice("repair"), "repair offered when damaged (S3)")
	actions.dialog.choose("repair")
	_check(player.health.missing_points() == 0.0, "repair restores shield and armour (S3)")
	_check(actions.dialog.has_choice("refuel"), "TR8: refuel offered when the tank isn't full")
	actions.dialog.choose("refuel")
	_check(is_equal_approx(GameState.travel.fuel, player.def.fuel), "TR8: refuelled to full")
	_check(GameState.credits == 1000 - ceili((player.def.fuel - 50.0) * haven.refuel_price), "TR8: paid the port's price (%d)" % GameState.credits)
	_check(not actions.dialog.has_choice("refuel"), "no refuel when full")
	var day_before_takeoff: int = GameState.clock.day
	actions.dialog.choose("take_off")
	await _frames(2)
	_check(not get_tree().paused and actions.dialog == null, "take off closes the screen and unpauses (S3)")
	_check(GameState.clock.day == day_before_takeoff + haven.takeoff_days, "TM2: take-off costs its days (0 by default)")

	# M5: boarding (C9).
	await _teleport(player, Vector2(-4000.0, -4000.0))
	var prize: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("trader_traffic"), Vector2(-4000.0, -3700.0), "", "steady")
	await _frames(2)
	prize.health.force_disable()
	prize.place(Vector2(-4000.0, -3700.0), 0.0)
	player.place(Vector2(-4000.0, -4000.0), 0.0)
	await _frames(2)
	_check(actions.try_board() == "far", "too far to board (C9)")
	player.place(prize.global_position + Vector2(prize.hull_half_width() + player.hull_half_width() + 10.0, 0.0), 0.0)
	_check(actions.try_board() == "", "boarding starts alongside (C9)")
	await _frames(30)
	_check(actions.board_progress() > 0.0 and actions.board_progress() < 1.0, "progress bar running (C9)")
	player.health.apply_damage(1.0, 0.0)
	_check(actions.boarding == null, "taking damage aborts boarding (C9)")
	actions.try_board()
	await _frames(roundi(float(DataRegistry.settings["boarding"]["time"]) * 60.0) + 5)
	_check(actions.dialog != null and get_tree().paused, "boarding window opens, game paused (C9)")
	_check(actions.dialog.has_choice("take") and actions.dialog.has_choice("assist"), "first boarding offers take and assist")
	var credits_before: int = GameState.credits
	var trader_record: float = GameState.get_record("independent_traders")
	var aboard: int = prize.credits_aboard
	actions.dialog.choose("take")
	_check(GameState.credits == credits_before + aboard and aboard > 0, "take credits (C9): +%d" % aboard)
	_check(GameState.get_record("independent_traders") < trader_record, "board penalty (G2)")
	await _frames(2)
	actions.try_board()
	await _frames(roundi(float(DataRegistry.settings["boarding"]["time"]) * 60.0) + 5)
	_check(actions.dialog != null and not actions.dialog.has_choice("assist") and actions.dialog.has_choice("scuttle"), "reboarding after looting: no assist (C9)")
	actions.dialog.choose("leave")
	await _frames(2)
	_check(is_instance_valid(prize) and prize.health.is_disabled, "leave: wreck stays (C9)")
	# Assist a second wreck.
	var stranded: Ship = traffic.spawn_from_pool(DataRegistry.get_ai_pool("trader_traffic"), Vector2(-3000.0, -3000.0), "", "steady")
	await _frames(2)
	stranded.health.force_disable()
	stranded.place(Vector2(-3000.0, -3000.0), 0.0)
	player.place(Vector2(-3000.0 + stranded.hull_half_width() + player.hull_half_width() + 10.0, -3000.0), 0.0)
	var record_before_assist: float = GameState.get_record("independent_traders")
	actions.try_board()
	await _frames(roundi(float(DataRegistry.settings["boarding"]["time"]) * 60.0) + 5)
	actions.dialog.choose("assist")
	await _frames(2)
	_check(not stranded.health.is_disabled and (stranded.controller as AIController).state == AIController.State.LEAVE, "assist: ship recovers and leaves (C9)")
	_check(GameState.get_record("independent_traders") > record_before_assist, "assist raises record (C9)")
	# Assist is once per ship: disable it again and the option is gone.
	stranded.health.force_disable()
	stranded.place(Vector2(-3000.0, -3000.0), 0.0)
	player.place(Vector2(-3000.0 + stranded.hull_half_width() + player.hull_half_width() + 10.0, -3000.0), 0.0)
	actions.try_board()
	await _frames(roundi(float(DataRegistry.settings["boarding"]["time"]) * 60.0) + 5)
	_check(actions.dialog != null and not actions.dialog.has_choice("assist"), "no second assist on the same ship (C9)")
	actions.dialog.choose("leave")
	await _frames(2)
	# A wreck freed mid-boarding cancels cleanly (freed objects compare equal to null).
	actions.try_board()
	await _frames(10)
	stranded.remove_from_group(&"ships")
	stranded.queue_free()
	await _frames(3)
	_check(actions.board_progress() < 0.0 and not player.health.damaged.is_connected(actions._on_player_hit_while_boarding), "freed wreck cancels boarding cleanly (C9)")
	# Scuttle the looted wreck.
	player.place(prize.global_position + Vector2(prize.hull_half_width() + player.hull_half_width() + 10.0, 0.0), 0.0)
	actions.try_board()
	await _frames(roundi(float(DataRegistry.settings["boarding"]["time"]) * 60.0) + 5)
	actions.dialog.choose("scuttle")
	await _frames(3)
	_check(not is_instance_valid(prize), "scuttle destroys it (C9)")
	_debug.clear_ships()
	await _frames(2)

	# M5: escape pod and rescue (C10).
	var wreck_before: Array[Ship] = _debug.spawn_ships("pirate_raider", 1)
	wreck_before[0].health.force_disable()
	GameState.set_credits(1000)
	var fee_pct: float = float(DataRegistry.settings["player"]["rescue_fee_pct"])
	player.place(Vector2(500.0, 500.0), 0.0)
	player.health.force_destroy()
	await _frames(2)
	_check(get_tree().get_nodes_in_group(&"escape_pod").size() == 1, "escape pod launched (C10)")
	await _frames(roundi(float(DataRegistry.settings["player"]["pod_time"]) * 60.0) + 5)
	_check(actions.dialog != null and get_tree().paused, "rescue report, paused (C10)")
	_check(GameState.credits == 1000 - roundi(1000.0 * fee_pct / 100.0), "rescue fee charged (C10): %d" % GameState.credits)
	var rescue_days: Array = DataRegistry.settings["player"]["rescue_days"]
	_check(GameState.clock.day >= day_before_takeoff + roundi(rescue_days[0]), "TM2: days adrift pass on the calendar")
	_check(not player.health.is_destroyed and player.health.missing_points() == 0.0, "insured: ship replaced and repaired (C10)")
	_check(not is_instance_valid(wreck_before[0]), "days passed: wrecks cleared (C10)")
	actions.dialog.choose("continue")
	await _frames(3)
	_check(actions.dialog != null and get_tree().paused, "wakes up landed at a port (C10)")
	actions.dialog.choose("take_off")
	await _frames(2)
	_check(not get_tree().paused, "take off after rescue")
	# No escape pod: lost with all hands.
	DataRegistry.settings["player"]["escape_pod"] = false
	player.health.force_destroy()
	await _frames(2)
	_check(actions.dialog != null and actions.dialog.has_choice("restart"), "no pod: lost with all hands (C10)")
	actions.dialog.close()
	DataRegistry.settings["player"]["escape_pod"] = true
	_debug.swap_player_ship("courier")
	await _frames(2)

	# M5: hold T to aim (F5) and the radar arrow (H2).
	player.place(Vector2.ZERO, 0.0)
	var mark: Array[Ship] = _debug.spawn_ships("shuttle", 1, "", Vector2(800.0, 0.0))
	await _frames(2)
	player.set_target(mark[0])
	Input.action_press(&"aim_target")
	var aim_input: FlightInput = player.controller.get_flight_input()
	Input.action_release(&"aim_target")
	_check(aim_input.turn > 0.0, "holding T turns toward a target on the right (F5)")
	_check(player.controller.get_flight_input().turn == 0.0, "released: no turning")
	_check(scene_root.hud.radar.target_off_radar() == Vector2.ZERO, "no arrow while in radar range")
	mark[0].place(Vector2(0.0, 20000.0), 0.0)
	_check(scene_root.hud.radar.target_off_radar().is_equal_approx(Vector2(0.0, 1.0)), "arrow points at a distant target (H2)")
	_debug.clear_ships()
	await _frames(2)

	# M5: debug console (D10) drives the same command layer as the panel.
	_check(_debug.run_command("help").begins_with("Commands:"), "help lists commands (D10)")
	_check(_debug.run_command("spawn pirate_raider 2 pirates") == "Spawned 2", "spawn via console (D10)")
	_check(_debug.run_command("credits 777") == "Credits 777" and GameState.credits == 777, "credits via console (D10)")
	_check(_debug.run_command("record pirates 25").begins_with("Record with pirates"), "record via console (D10)")
	_check(_debug.run_command("invuln on") == "invuln on" and player.health.invulnerable, "invuln via console (D10)")
	_debug.run_command("invuln off")
	_check(_debug.run_command("spawn pirate_raider lots").begins_with("Count must"), "bad count is reported (D10)")
	_check(_debug.run_command("frobnicate").begins_with("Unknown command"), "unknown command is reported (D10)")
	_debug.toggle_console()
	Input.action_press(&"thrust")
	_check(not player.controller.get_flight_input().thrust, "typing in the console doesn't fly the ship (D10)")
	Input.action_release(&"thrust")
	_debug.toggle_console()
	_check(_debug.run_command("clear").begins_with("Removed"), "clear via console")
	GameState.set_record("pirates", 0.0)
	await _frames(2)

	# P2M1: hyperspace and the day clock (TR2–TR4, TR7, TR8, TM2, D11).
	var traffic_was_on: bool = _debug.is_traffic_enabled()
	_debug.set_traffic_enabled(false)
	_debug.clear_ships()
	await _hyperspace_checks(player, scene_root)
	_debug.set_traffic_enabled(traffic_was_on)

	# System switch (D11 goto).
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
	# H2: radar scenery shows out to the full radar range, not just loaded chunks.
	var radar_range: float = float(DataRegistry.settings["radar"]["range"])
	await _teleport(player, Vector2(9000.0, 0.0))
	var far_points: Array[Vector2] = local_space.distant_radar_points(player.global_position, radar_range)
	_check(far_points.size() > 0, "H2: distant hulls in radar range show before their chunks load")
	_check(far_points.all(func(at: Vector2) -> bool: return at.distance_to(player.global_position) <= radar_range), "only within radar range")
	if far_points.size() > 0:
		var probe: Vector2 = far_points[0]
		await _teleport(player, probe)
		var nearest: float = INF
		for sc: Scenery in local_space.radar_objects():
			nearest = minf(nearest, sc.global_position.distance_to(probe))
		_check(nearest < 2.0, "H2: a distant radar point is where the hull is once loaded (%.1f px)" % nearest)
		_check(not local_space.distant_radar_points(probe, 600.0).has(probe), "loaded chunks aren't counted twice")
	await _teleport(player, Vector2(2200.0, 0.0))
	hud = scene_root.hud
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


func actions_of(scene_root: Node) -> PlayerActions:
	return scene_root.actions


## Sends a key press as an action event and waits until it has been handled
## (input is delivered on process frames, not physics frames).
func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


## P2M1: jump checks, cancelling, a full jump and the D11 commands.
func _hyperspace_checks(player: Ship, scene_root: Node) -> void:
	var hyper: Hyperspace = scene_root.hyperspace
	var travel: TravelState = GameState.travel
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var P := JumpSequence.Phase
	_check(travel.current_system == galaxy.start_system, "starts in the galaxy's start system (TR1)")
	_check(travel.map_state(galaxy, galaxy.start_system) == "explored", "start system is explored (TR7)")
	_debug.refuel()
	travel.route.clear()
	await _teleport(player, Vector2.ZERO)
	_check(hyper.try_jump() == Hyperlanes.NO_DESTINATION, "TR2: no jump without a destination")
	_check(not hyper.plot_to("hollow"), "TR7: a hidden system can't be routed to")
	await _press(&"galaxy_map")
	await _frames(2)
	var map: GalaxyMap = hyper.map
	_check(map != null and get_tree().paused, "TR7: M opens the map and pauses")
	if map != null:
		_check(not map._screen_points().has("hollow"), "TR7: hidden systems aren't drawn")
		_check(map._screen_points().size() == galaxy.system_ids.size() - 1, "every other system is drawn")
		_check(map.select("lumen") and travel.route.size() == 2, "TR7: clicking lumen plots a two-jump route (%s)" % [travel.route])
		_check(map._title.text == "Unexplored system" and map._info.text.contains("2 jumps"), "TR7: unexplored panel shows route cost")
		map.select(travel.current_system)
		_check(map._title.text == scene_root.system.name and map._info.text.contains("You are here"), "explored panel")
		map.select("lumen")
		await _press(&"galaxy_map")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(hyper.map == null and not get_tree().paused, "M closes the map and unpauses")
	_check(travel.route.size() == 2 and travel.route[-1] == "lumen", "route kept after closing the map")
	var destination: String = travel.destination()
	_check(hyper.try_jump() == Hyperlanes.INSIDE, "TR2: no jump inside the jump radius")
	var radius: float = scene_root.system.jump_radius
	await _teleport(player, Vector2(radius + 400.0, 0.0))
	travel.fuel = 10.0
	_check(hyper.try_jump() == Hyperlanes.NO_FUEL, "TR2: no jump without enough fuel")
	_debug.refuel()

	_check(hyper.try_jump() == "", "jump starts")
	await _press(&"jump")
	await _frames(2)
	_check(not hyper.is_active() and player.autopilot == null, "TR2: pressing J again cancels")
	_check(hyper.try_jump() == "", "jump restarts")
	await _press(&"fire_primary")
	await _frames(2)
	Input.action_release(&"fire_primary")
	_check(not hyper.is_active(), "TR2: firing cancels")
	_check(hyper.try_jump() == "", "jump restarts again")
	player.health.apply_damage(5.0, 0.0)
	await _frames(2)
	_check(hyper.is_active(), "TR2: hits don't cancel")
	player.health.force_disable()
	await _frames(2)
	_check(not hyper.is_active() and player.autopilot == null, "TR2: being disabled cancels")
	player.health.repair_full()
	player.set_tint(Color.WHITE)

	# A full jump: moving fast across the bearing, so it has to stop and turn.
	var origin: String = travel.current_system
	var bearing: Vector2 = Hyperlanes.bearing(galaxy, origin, destination)
	player.place(Vector2(radius + 400.0, 0.0), 0.0, bearing.orthogonal() * player.def.top_speed)
	await _frames(2)
	var day_before: int = GameState.clock.day
	var fuel_before: float = travel.fuel
	_check(hyper.try_jump() == "", "full jump starts")
	Input.action_press(&"thrust")
	await _frames(2)
	_check(not player.get_flight_input().thrust or hyper.sequence.phase == P.STOPPING, "TR2: the player's thrust key is ignored")
	Input.action_release(&"thrust")
	_check(actions_of(scene_root).try_land() == "none" and actions_of(scene_root).try_board() == "none", "no landing or boarding mid-jump")
	_check(hyper.open_map() == null, "map locked mid-jump")
	var phases: Array[int] = []
	var countdown_ticks: int = 0
	for i: int in 60 * 40:
		if not hyper.is_active():
			break
		if phases.is_empty() or phases[-1] != hyper.sequence.phase:
			phases.append(hyper.sequence.phase)
		if hyper.sequence.phase == P.COUNTDOWN:
			countdown_ticks += 1
			_check(player.get_velocity().is_zero_approx(), "TR2: stopped during the countdown")
		await get_tree().physics_frame
	var countdown_s: float = float(countdown_ticks) / Engine.physics_ticks_per_second
	_check(absf(countdown_s - player.def.jump_countdown) < 0.1, "TR2: countdown lasts its data time (%.2f s, want %.1f)" % [countdown_s, player.def.jump_countdown])
	await _frames(2)
	_check(phases == [P.STOPPING, P.ALIGNING, P.COUNTDOWN, P.OVERDRIVE], "TR2: stop, align, countdown, overdrive (%s)" % [phases])
	_check(travel.current_system == destination and scene_root.system.id == destination, "TR2: arrived in %s" % destination)
	var length: float = Hyperlanes.lane_length(galaxy, origin, destination)
	_check(GameState.clock.day == day_before + Hyperlanes.jump_days(length, player.def.jump_speed), "TM2: the jump cost its days")
	_check(is_equal_approx(travel.fuel, fuel_before - player.def.jump_fuel), "TR8: the jump cost its fuel")
	var new_radius: float = scene_root.system.jump_radius
	_check(absf(player.global_position.length() - new_radius) < 60.0, "TR4: arrives at the jump radius (%f)" % player.global_position.length())
	_check(player.global_position.normalized().dot(-bearing) > 0.99, "TR4: arrives on the side facing the origin")
	var arrival_speed: float = player.def.top_speed * float(DataRegistry.settings["hyperspace"]["arrival_speed_fraction"])
	_check(player.get_velocity().normalized().dot(bearing) > 0.99 and absf(player.get_velocity().length() - arrival_speed) < 1.0, "TR4: moving inward at reduced speed")
	_check(travel.map_state(galaxy, destination) == "explored", "TR7: visiting explores")
	_check(travel.destination() == "lumen", "TR7: the next leg is selected")
	_check(get_tree().get_nodes_in_group(&"ships").size() == 1, "only the player came through")

	# D11
	var day_now: int = GameState.clock.day
	_check(_debug.run_command("days 5").begins_with("Date"), "days via console (D11)")
	_check(GameState.clock.day == day_now + 5, "D11: five days passed")
	_check(_debug.run_command("reveal hollow").begins_with("Revealed"), "reveal via console")
	_check(travel.map_state(galaxy, "hollow") == "unexplored", "TR7: revealed system is unexplored")
	_check(_debug.run_command("goto test_nebula").begins_with("Arrived"), "goto via console (D11)")
	_check(travel.current_system == "test_nebula" and GameState.clock.day == day_now + 5, "D11: goto costs no days")
	_check(not _debug.switch_system("nowhere"), "goto refuses unknown systems")
	_debug.refuel()


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
