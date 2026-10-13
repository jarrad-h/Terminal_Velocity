class_name PlayerController
extends Node
## Reads keyboard input into FlightInput (F1). Gamepad bindings come later.


func get_flight_input() -> FlightInput:
	return FlightInput.new(
		Input.is_action_pressed(&"thrust"),
		Input.get_axis(&"turn_left", &"turn_right"),
		Input.is_action_pressed(&"reverse"),
	)


func get_state_label() -> String:
	return "player"
