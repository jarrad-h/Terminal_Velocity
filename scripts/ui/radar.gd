class_name Radar
extends Control
## H2: a round radar in the bottom-right corner, centred on the player.
## Ships are coloured by hostility to the player (hostile, friendly, neutral when
## they have no government); system objects
## beyond range sit on the rim as hollow pips; scenery appears only for types
## with radar: true, read from LocalSpace's short list rather than by scanning
## every scenery node. Size, range and colours come from game.json "radar".

var player: Ship = null
var _range: float = 3000.0
var _radius: float = 90.0
var _colours: Dictionary = {}


func configure(settings: Dictionary) -> void:
	_radius = float(settings["size"]) / 2.0
	_range = float(settings["range"])
	var margin: float = float(settings["margin"])
	_colours = {}
	for key: String in settings["colours"]:
		_colours[key] = Color.html(settings["colours"][key])
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -margin - _radius * 2.0
	offset_top = -margin - _radius * 2.0
	offset_right = -margin
	offset_bottom = -margin
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var centre := Vector2(_radius, _radius)
	draw_circle(centre, _radius, _colours["background"])
	draw_arc(centre, _radius, 0.0, TAU, 64, _colours["rim"], 1.5)
	if player == null or not is_instance_valid(player):
		return
	var origin: Vector2 = player.global_position
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if scene != null and scene.system != null:
		for obj: SystemObjectDef in scene.system.objects:
			var p: Vector2 = _to_radar(obj.position - origin)
			if p.length() > _radius - 3.0:
				draw_arc(centre + p.limit_length(_radius - 4.0), 3.0, 0.0, TAU, 12, obj.colour, 1.5)
			else:
				draw_circle(centre + p, clampf(obj.radius / _range * _radius, 3.0, 8.0), obj.colour)
		for scenery: Scenery in scene.local_space.radar_objects():
			if is_instance_valid(scenery):
				_dot(centre, _to_radar(scenery.global_position - origin), 1.5, _colours["scenery"])
	var target: Ship = player.get_target()
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node
		if ship == player or not ship.visible:
			continue
		var p: Vector2 = _to_radar(ship.global_position - origin)
		if DebugCommands.radar_show_all and p.length() > _radius - 2.5:
			p = p.limit_length(_radius - 2.5)  # D4: show every ship, on the rim
		_dot(centre, p, 2.5, _ship_colour(ship))
		if ship == target and p.length() <= _radius:
			draw_arc(centre + p, 6.0, 0.0, TAU, 16, _colours["target"], 1.5)
	# H2: an arrow on the rim pointing at a target beyond radar range.
	var arrow: Vector2 = target_off_radar()
	if arrow != Vector2.ZERO:
		var tip: Vector2 = centre + arrow * (_radius - 1.0)
		var back: Vector2 = centre + arrow * (_radius - 11.0)
		var side: Vector2 = arrow.orthogonal() * 6.0
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), _colours["target"])
	draw_circle(centre, 2.5, _colours["player"])


func _to_radar(offset: Vector2) -> Vector2:
	return offset / _range * _radius


func _dot(centre: Vector2, p: Vector2, size: float, colour: Color) -> void:
	if p.length() <= _radius - size:
		draw_rect(Rect2(centre + p - Vector2(size, size), Vector2(size, size) * 2.0), colour)


## H2: by hostility to the player; ships with no government are neutral.
func _ship_colour(ship: Ship) -> Color:
	if player.is_hostile_to(ship):
		return _colours["hostile"]
	if ship.grievance > 0.0:
		return _colours["warned"]  # A8: annoyed, not yet hostile
	return _colours["friendly"] if ship.government != "" else _colours["neutral"]


## H2: direction to the selected target when it is beyond radar range, else zero.
func target_off_radar() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var target: Ship = player.get_target()
	if target == null:
		return Vector2.ZERO
	var offset: Vector2 = target.global_position - player.global_position
	return offset.normalized() if offset.length() > _range else Vector2.ZERO
