class_name DebugOverlay
extends Node2D
## D9 world-space overlays: hitboxes (capsules, with hardpoints, their arcs
## and engine exits), velocity vectors and AI state labels.
## Lives under the World node so it draws in world coordinates.

const HITBOX_COLOUR := Color(0.2, 1.0, 0.3, 0.8)
const SCENERY_HITBOX_COLOUR := Color(0.3, 0.8, 1.0, 0.6)
const HARDPOINT_COLOUR := Color(1.0, 0.4, 0.9, 0.9)
const ENGINE_COLOUR := Color(0.4, 0.8, 1.0, 0.9)
## Length of the arc and barrel lines drawn at each hardpoint, px.
const ARC_LINE: float = 40.0
const VELOCITY_COLOUR := Color(1.0, 0.8, 0.2)
const LABEL_COLOUR := Color(0.8, 0.9, 1.0)
const LABEL_FONT_SIZE: int = 12
const LABEL_WIDTH: float = 320.0


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
		if not ship.visible:
			continue
		var pos: Vector2 = ship.global_position
		if show_hitboxes:
			_draw_ship_hitbox(ship)
		if show_velocity:
			draw_line(pos, pos + ship.get_velocity() * vector_seconds, VELOCITY_COLOUR, 2.0)
		if show_labels:
			var at := pos + Vector2(-LABEL_WIDTH / 2.0, -ship.hit_radius - 6.0)
			draw_string(font, at, ship.get_state_label(), HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, LABEL_FONT_SIZE, LABEL_COLOUR)


## V2, V3, V5: the capsule, each hardpoint with its barrel and arc, and the
## engine exits, drawn in the ship's frame.
func _draw_ship_hitbox(ship: Ship) -> void:
	draw_set_transform(ship.global_position, ship.global_rotation)
	var size: Vector2 = ship.def.hit_size * ship.art_scale
	var centre: Vector2 = ship.def.hit_offset * ship.art_scale
	var r: float = size.x / 2.0
	var half: float = maxf(size.y - size.x, 0.0) / 2.0
	draw_arc(centre + Vector2(0.0, -half), r, PI, TAU, 16, HITBOX_COLOUR, 1.0)
	draw_arc(centre + Vector2(0.0, half), r, 0.0, PI, 16, HITBOX_COLOUR, 1.0)
	draw_line(centre + Vector2(-r, -half), centre + Vector2(-r, half), HITBOX_COLOUR, 1.0)
	draw_line(centre + Vector2(r, -half), centre + Vector2(r, half), HITBOX_COLOUR, 1.0)
	for mount: WeaponMounts.Mount in ship.weapons.mounts:
		var p: Vector2 = mount.point
		draw_circle(p, 2.5, HARDPOINT_COLOUR)
		draw_line(p, p + Vector2.UP.rotated(mount.angle) * ARC_LINE, HARDPOINT_COLOUR, 1.0)
		if mount.tracks() and mount.arc < 360.0:
			var half_arc: float = deg_to_rad(mount.arc) / 2.0
			for side: float in [-half_arc, half_arc]:
				draw_line(p, p + Vector2.UP.rotated(side) * ARC_LINE, Color(HARDPOINT_COLOUR, 0.4), 1.0)
	for e: Vector2 in ship.def.engines:
		draw_circle(e * ship.art_scale, 2.0, ENGINE_COLOUR)
	draw_set_transform(Vector2.ZERO)
