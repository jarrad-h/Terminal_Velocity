class_name DebugOverlay
extends Node2D
## D9 world-space overlays: hitboxes, velocity vectors and AI state labels.
## Lives under the World node so it draws in world coordinates.

const HITBOX_COLOUR := Color(0.2, 1.0, 0.3, 0.8)
const SCENERY_HITBOX_COLOUR := Color(0.3, 0.8, 1.0, 0.6)
const VELOCITY_COLOUR := Color(1.0, 0.8, 0.2)
const LABEL_COLOUR := Color(0.8, 0.9, 1.0)
const LABEL_FONT_SIZE: int = 12


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var show_hitboxes: bool = DebugCommands.is_overlay_enabled(&"hitboxes")
	var show_velocity: bool = DebugCommands.is_overlay_enabled(&"velocity")
	var show_labels: bool = DebugCommands.is_overlay_enabled(&"ai_labels")
	if not (show_hitboxes or show_velocity or show_labels):
		return
	var vector_seconds: float = float(DataRegistry.settings["debug"]["velocity_vector_seconds"])
	var font: Font = ThemeDB.fallback_font
	if show_hitboxes:
		for node: Node in get_tree().get_nodes_in_group(&"solid_scenery"):
			var scenery: Scenery = node
			draw_arc(scenery.global_position, scenery.hit_radius, 0.0, TAU, 24, SCENERY_HITBOX_COLOUR, 1.0)
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node
		var pos: Vector2 = ship.global_position
		if show_hitboxes:
			draw_arc(pos, ship.hit_radius, 0.0, TAU, 32, HITBOX_COLOUR, 1.0)
		if show_velocity:
			draw_line(pos, pos + ship.get_velocity() * vector_seconds, VELOCITY_COLOUR, 2.0)
		if show_labels:
			var at := pos + Vector2(-50.0, -ship.hit_radius - 6.0)
			draw_string(font, at, ship.get_state_label(), HORIZONTAL_ALIGNMENT_CENTER, 100.0, LABEL_FONT_SIZE, LABEL_COLOUR)
