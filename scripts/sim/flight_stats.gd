class_name FlightStats
extends RefCounted
## Flight values from a ship definition (F3). Units: px/s², px/s, degrees/s.

var accel: float = 0.0
var top_speed: float = 0.0
var turn_rate: float = 0.0


func _init(p_accel: float = 0.0, p_top_speed: float = 0.0, p_turn_rate: float = 0.0) -> void:
	accel = p_accel
	top_speed = p_top_speed
	turn_rate = p_turn_rate


static func from_ship_def(def: ShipDef) -> FlightStats:
	return FlightStats.new(def.accel, def.top_speed, def.turn_rate)
