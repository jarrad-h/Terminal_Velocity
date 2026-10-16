extends Node
## Smoke test: runs the system scene, presses flight keys and exercises every
## debug command. Run as a scene so autoloads exist:
##   godot --headless --path . res://tests/smoke_system.tscn

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
	player.target_nearest()
	var target: Ship = player.get_target()
	_check(target != null and target.def.id == "target_dummy", "nearest target is the dummy")
	player.cycle_target()
	_check(player.get_target() == target, "cycling with one candidate keeps it")

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

	# System switch.
	_check(_debug.switch_system("test_graveyard"), "switch to test_graveyard")
	_check(_debug.current_system_id() == "test_graveyard", "current system updated")
	await _teleport(player, Vector2(2200.0, 0.0))
	var hulls: int = 0
	for node: Node in local_space.find_children("*", "Scenery", true, false):
		if (node as Scenery).def.id == "derelict_hull":
			hulls += 1
	_check(hulls > 0, "graveyard ring has derelict hulls")
	_check(not _debug.switch_system("nowhere"), "unknown system is refused")
	await _frames(5)
	_finish()


func _teleport(ship: Ship, at: Vector2) -> void:
	ship.body.state = FlightState.new(at, Vector2.ZERO, 0.0)
	await _frames(3)


func _chunk_snapshot(local_space: LocalSpace, chunk: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var holder: Node = local_space.get_node_or_null("Chunk_%d_%d" % [chunk.x, chunk.y])
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
	print("smoke: %d failures" % _errors.size())
	get_tree().quit(1 if _errors.size() > 0 else 0)
