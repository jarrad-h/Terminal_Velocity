class_name PlayerController
extends Node
## Reads keyboard input into FlightInput (F1) and handles targeting keys (C8).
## Gamepad bindings come later.


func get_flight_input() -> FlightInput:
	return FlightInput.new(
		Input.is_action_pressed(&"thrust"),
		Input.get_axis(&"turn_left", &"turn_right"),
		Input.is_action_pressed(&"reverse"),
	)


func get_state_label() -> String:
	return "player"


func _unhandled_input(event: InputEvent) -> void:
	var ship: Ship = get_parent()
	if event.is_action_pressed(&"target_nearest"):
		ship.target_nearest()
	elif event.is_action_pressed(&"target_cycle"):
		ship.cycle_target()
	else:
		return
	get_viewport().set_input_as_handled()
