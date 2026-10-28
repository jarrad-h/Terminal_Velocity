class_name PlayerController
extends Node
## Reads keyboard input into FlightInput (F1), holds aim on the target with T
## (F5) and handles targeting keys (C8).
## Gamepad bindings come later.


func get_flight_input() -> FlightInput:
	var input := FlightInput.new(
		Input.is_action_pressed(&"thrust"),
		Input.get_axis(&"turn_left", &"turn_right"),
		Input.is_action_pressed(&"reverse"),
	)
	input.fire_primary = Input.is_action_pressed(&"fire_primary")
	input.fire_secondary = Input.is_action_pressed(&"fire_secondary")
	# F5: holding T turns toward the target's lead point instead.
	var ship: Ship = get_parent()
	var target: Ship = ship.get_target()
	if Input.is_action_pressed(&"aim_target") and target != null:
		var state: FlightState = ship.body.state
		var aim: Vector2 = (target.global_position - state.position).normalized()
		var shot_speed: float = ship.weapons.primary_shot_speed()
		if shot_speed > 0.0:
			var shot_frame: Vector2 = state.velocity  # guns inherit the ship's velocity
			aim = Aim.intercept_direction(state.position, target.global_position, target.get_velocity() - shot_frame, shot_speed)
		input.turn = Steering.face(state, ship.body.stats, aim, get_physics_process_delta_time()).turn
	return input


func get_state_label() -> String:
	return "player"


## C8: R nearest hostile, Tab nearest of any kind, Shift+R cycle hostiles,
## Shift+Tab cycle all. Exact matching keeps Shift+R from also firing R.
func _unhandled_input(event: InputEvent) -> void:
	var ship: Ship = get_parent()
	if event.is_action_pressed(&"target_cycle_hostile", false, true):
		ship.cycle_target(true)
	elif event.is_action_pressed(&"target_cycle", false, true):
		ship.cycle_target(false)
	elif event.is_action_pressed(&"target_nearest", false, true):
		ship.target_nearest(true)
	elif event.is_action_pressed(&"target_nearest_any", false, true):
		ship.target_nearest(false)
	else:
		return
	get_viewport().set_input_as_handled()
