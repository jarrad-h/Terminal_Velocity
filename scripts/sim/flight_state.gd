class_name FlightState
extends RefCounted
## Kinematic state of one ship. Rotation 0 faces up (-Y); positive is clockwise.

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var rotation: float = 0.0


func _init(p_position: Vector2 = Vector2.ZERO, p_velocity: Vector2 = Vector2.ZERO, p_rotation: float = 0.0) -> void:
	position = p_position
	velocity = p_velocity
	rotation = p_rotation


func copy() -> FlightState:
	return FlightState.new(position, velocity, rotation)
