class_name ShipBody
extends Node
## Flight model node: each physics frame, asks the ship for input, steps
## FlightModel and writes the result to the parent Ship's transform.

var stats: FlightStats = FlightStats.new()
var state: FlightState = FlightState.new()

@onready var ship: Ship = get_parent()


func _ready() -> void:
	state = FlightState.new(ship.position, Vector2.ZERO, ship.rotation)


func _physics_process(delta: float) -> void:
	var input: FlightInput = ship.get_flight_input()  # may hold the ship still (TR2)
	state = FlightModel.step(state, input, ship.flight_stats(), delta)
	ship.position = state.position
	ship.rotation = state.rotation
