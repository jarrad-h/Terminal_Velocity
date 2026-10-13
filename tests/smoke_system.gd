extends SceneTree
## Smoke test: runs the system scene, presses flight keys and exercises every
## debug command. Run with:
##   godot --headless --path . --script res://tests/smoke_system.gd

var _errors: Array[String] = []
## Autoloads are not global identifiers in --script runners; fetch the node.
var _debug: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	_debug = root.get_node(^"DebugCommands")
	var scene: Node = load("res://scenes/system.tscn").instantiate()
	root.add_child(scene)
	await _frames(2)
	var player: Ship = get_first_node_in_group(&"player")
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
	await process_frame
	await process_frame
	_check(player.position == paused_at, "pause stops the ship")
	_debug.step_frame()
	await _frames(5)
	var step_delta: float = player.position.distance_to(paused_at)
	var expected: float = player.get_velocity().length() / Engine.physics_ticks_per_second
	_check(absf(step_delta - expected) < 0.01, "step advances exactly one physics frame (moved %f, expected %f)" % [step_delta, expected])
	_check(paused, "still paused after step")
	_debug.set_paused(false)
	await _frames(5)
	_finish()


func _finish() -> void:
	for e: String in _errors:
		print("FAIL ", e)
	print("smoke: %d failures" % _errors.size())
	quit(1 if _errors.size() > 0 else 0)
