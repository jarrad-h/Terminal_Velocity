class_name EngineGlow
extends Node2D
## V5: a glow at each engine exit, bright while thrusting and faint at idle.

## Idle glow strength as a share of full thrust (cosmetic).
const IDLE: float = 0.25

var points: Array[Vector2] = []
var colour: Color = Color.WHITE
var size: float = 6.0
var _strength: float = 0.0

@onready var ship: Ship = owner_ship()


func owner_ship() -> Ship:
	var node: Node = get_parent()
	while node != null and not node is Ship:
		node = node.get_parent()
	return node


func _process(delta: float) -> void:
	if ship == null:
		return
	var thrusting: bool = ship.can_act() and ship.get_flight_input().thrust
	var goal: float = 1.0 if thrusting else (IDLE if ship.can_act() else 0.0)
	_strength = move_toward(_strength, goal, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _strength <= 0.0:
		return
	for p: Vector2 in points:
		var tail: Vector2 = p + Vector2(0.0, size * 1.6 * _strength)
		draw_circle(tail, size * 1.3 * _strength, Color(colour, 0.18 * _strength))
		draw_circle(p + Vector2(0.0, size * 0.5 * _strength), size * 0.8 * _strength, Color(colour, 0.45 * _strength))
		draw_circle(p, size * 0.45, Color(colour.lerp(Color.WHITE, 0.6), 0.9 * _strength))
