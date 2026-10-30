class_name TargetMarker
extends Node2D
## Draws corner brackets round the player's selected target (C8).

const COLOUR := Color(1.0, 0.95, 0.3, 0.9)


func _init() -> void:
	material = LitSprite.unshaded_material()  # V6: full brightness, not lit or darkened


func _ready() -> void:
	z_index = 50


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var target: Ship = player.get_target()
	if target == null:
		return
	var c: Vector2 = target.global_position
	var r: float = target.hit_radius + 8.0
	var arm: float = r * 0.4
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = c + corner * r
		draw_line(p, p - Vector2(corner.x * arm, 0.0), COLOUR, 2.0)
		draw_line(p, p - Vector2(0.0, corner.y * arm), COLOUR, 2.0)
