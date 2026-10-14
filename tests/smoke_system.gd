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

	# System switch.
	_check(_debug.switch_system("test_graveyard"), "switch to test_graveyard")
	_check(_debug.current_system_id() == "test_graveyard", "current system updated")
	_check(not _debug.switch_system("nowhere"), "unknown system is refused")
	await _frames(5)
	_finish()


func _finish() -> void:
	for e: String in _errors:
		print("FAIL ", e)
	print("smoke: %d failures" % _errors.size())
	get_tree().quit(1 if _errors.size() > 0 else 0)
