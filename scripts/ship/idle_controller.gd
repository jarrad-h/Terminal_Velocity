class_name IdleController
extends Node
## Does nothing: used for the target dummy and debug-spawned ships until the
## AI controllers arrive in milestone 4.


func get_flight_input() -> FlightInput:
	return FlightInput.new()


func get_state_label() -> String:
	return "idle"
