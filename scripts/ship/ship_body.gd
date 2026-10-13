class_name ShipBody
extends Node
## Flight model node: each physics frame, asks the ship for input, steps
## FlightModel and writes the result to the parent Ship's transform.

var stats: FlightStats = FlightStats.new()
var state: FlightState = FlightState.new()

@onready var ship: Ship = get_parent()


func _physics_process(delta: float) -> void:
	state = FlightModel.step(state, ship.get_flight_input(), stats, delta)
	ship.position = state.position
	ship.rotation = state.rotation
