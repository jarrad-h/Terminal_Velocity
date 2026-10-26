class_name Beam
extends Node2D
## C4: a beam mount's ray. Child of the ship at the exit point, pointing along
## the heading; while firing it hits the first hitbox along its length every
## physics frame, applying damage per second.

var weapon: WeaponDef
var _length: float = 0.0


func _ready() -> void:
	visible = false


## Fires for one physics frame.
func fire(shooter: Node, exclude: Array[RID], delta: float) -> void:
	var from: Vector2 = global_position
	var direction: Vector2 = FlightModel.heading(global_rotation)
	var hit: Dictionary = HitQuery.ray(self, from, from + direction * weapon.beam_length(), exclude)
	if hit.is_empty():
		_length = weapon.beam_length()
	else:
		_length = from.distance_to(hit["position"])
		var scale: float = HitQuery.damage_scale(shooter, hit["target"]) * delta
		if scale > 0.0:
			hit["target"].health.apply_damage(weapon.damage_shield * scale, weapon.damage_armor * scale, shooter)
	visible = true
	queue_redraw()


func stop() -> void:
	visible = false


func _draw() -> void:
	var end := Vector2(0.0, -_length)
	draw_line(Vector2.ZERO, end, Color(weapon.colour, 0.35), 6.0)
	draw_line(Vector2.ZERO, end, weapon.colour, 2.0)
