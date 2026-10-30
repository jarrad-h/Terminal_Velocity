class_name SystemObjects
extends Node2D
## S1 (placeholder art): draws the system's star, planets and stations from
## the system file as flat circles with names. Landing arrives in milestone 5.

const LABEL_SIZE: int = 16
const LABEL_COLOUR := Color(0.85, 0.9, 1.0, 0.9)

var system: SystemDef = null


func configure(p_system: SystemDef) -> void:
	system = p_system
	queue_redraw()


func _draw() -> void:
	if system == null:
		return
	var font: Font = ThemeDB.fallback_font
	for obj: SystemObjectDef in system.objects:
		var c: Vector2 = obj.position
		match obj.type:
			"star":
				for i: int in 4:
					draw_circle(c, obj.radius * (1.0 + 0.25 * (4 - i)), Color(obj.colour, 0.06))
				draw_circle(c, obj.radius, obj.colour)
			"gate":
				draw_arc(c, obj.radius, 0.0, TAU, 64, obj.colour, 24.0)
				var field: Color = Color(0.55, 0.45, 0.9, 0.35) if GateRules.is_open(obj.open_condition, GameState.flags) else Color(0.2, 0.2, 0.25, 0.3)
				draw_circle(c, obj.radius - 12.0, field)
			"station":
				draw_circle(c, obj.radius, obj.colour.darkened(0.6))
				draw_arc(c, obj.radius, 0.0, TAU, 48, obj.colour, 4.0)
				draw_arc(c, obj.radius * 0.45, 0.0, TAU, 32, obj.colour, 3.0)
			_:
				draw_circle(c, obj.radius, obj.colour)
				draw_arc(c, obj.radius, 0.0, TAU, 64, obj.colour.lightened(0.3), 2.0)
		draw_string(font, c + Vector2(-150.0, obj.radius + 24.0), obj.name, HORIZONTAL_ALIGNMENT_CENTER, 300.0, LABEL_SIZE, LABEL_COLOUR)
