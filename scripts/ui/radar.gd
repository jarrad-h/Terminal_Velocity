class_name Radar
extends Control
## H2: a round radar in the bottom-right corner, centred on the player.
## Ships are coloured by government (hostility arrives in M4); system objects
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
		_dot(centre, p, 2.5, _ship_colour(ship))
		if ship == target and p.length() <= _radius:
			draw_arc(centre + p, 6.0, 0.0, TAU, 16, _colours["target"], 1.5)
	draw_circle(centre, 2.5, _colours["player"])


func _to_radar(offset: Vector2) -> Vector2:
	return offset / _range * _radius


func _dot(centre: Vector2, p: Vector2, size: float, colour: Color) -> void:
	if p.length() <= _radius - size:
		draw_rect(Rect2(centre + p - Vector2(size, size), Vector2(size, size) * 2.0), colour)


func _ship_colour(ship: Ship) -> Color:
	var gov: GovernmentDef = DataRegistry.get_government(ship.government) if ship.government != "" else null
	return gov.colour if gov != null else _colours["neutral"]
