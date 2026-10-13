class_name FlightInput
extends RefCounted
## One frame of flight intent, produced by a controller (player or AI).

var thrust: bool = false
## -1 = full left (anticlockwise), +1 = full right (clockwise).
var turn: float = 0.0
## Turn to face opposite the current velocity. Ignored while `turn` is non-zero.
var reverse: bool = false


func _init(p_thrust: bool = false, p_turn: float = 0.0, p_reverse: bool = false) -> void:
	thrust = p_thrust
	turn = p_turn
	reverse = p_reverse
