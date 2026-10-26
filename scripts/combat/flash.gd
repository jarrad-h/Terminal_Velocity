class_name Flash
extends Node2D
## Cosmetic expanding, fading ring for hits and explosions.

var radius: float = 10.0
var colour: Color = Color(1.0, 0.8, 0.4)
var duration: float = 0.4
var _age: float = 0.0


static func spawn(parent: Node, at: Vector2, p_radius: float, p_colour: Color, p_duration: float) -> void:
	var flash := Flash.new()
	flash.global_position = at
	flash.radius = p_radius
	flash.colour = p_colour
	flash.duration = p_duration
	parent.add_child(flash)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t: float = _age / duration
	var c := Color(colour, 1.0 - t)
	draw_circle(Vector2.ZERO, radius * (0.3 + t), Color(c, c.a * 0.4))
	draw_arc(Vector2.ZERO, radius * (0.3 + t), 0.0, TAU, 24, c, 2.0)
