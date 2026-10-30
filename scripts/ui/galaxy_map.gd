class_name GalaxyMap
extends CanvasLayer
## TR7: the galaxy map (M). Pauses the game while open. Shows systems and
## hyperlanes (hidden systems and their lanes are left out), explored and
## unexplored systems, your system and the plotted route with its days and
## fuel. Clicking a system selects it and plots the fewest-days route there;
## beside the map, a stylised view of the selected system (explored only).
## M or Esc closes.

signal closed

const PICK_RADIUS: float = 16.0
const DOT_RADIUS: float = 7.0
const MAP_MARGIN: float = 48.0
const FONT_SIZE: int = 14
const VIEW_SIZE: float = 340.0
const ICON_SMALL: float = 16.0

var hyperspace: Hyperspace
## The system shown in the side panel.
var selected: String = ""
var _map: Control
var _view: Control
var _title: Label
var _info: Label
var _colours: Dictionary = {}
var _was_paused: bool = false


static func open(parent: Node, p_hyperspace: Hyperspace) -> GalaxyMap:
	var map := GalaxyMap.new()
	map.hyperspace = p_hyperspace
	var travel: TravelState = GameState.travel
	map.selected = travel.route[-1] if not travel.route.is_empty() else travel.current_system
	parent.add_child(map)
	return map


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_colours = DataRegistry.settings["galaxy_map"]["colours"]
	var shade := ColorRect.new()
	shade.color = Color.html(_colours["background"])
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	_map.resized.connect(_map.queue_redraw)
	row.add_child(_map)
	var side_box := VBoxContainer.new()
	side_box.custom_minimum_size = Vector2(VIEW_SIZE, 0.0)
	side_box.add_theme_constant_override("separation", 12)
	row.add_child(side_box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	side_box.add_child(_title)
	_view = Control.new()
	_view.custom_minimum_size = Vector2(VIEW_SIZE, VIEW_SIZE)
	_view.draw.connect(_draw_view)
	side_box.add_child(_view)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(VIEW_SIZE, 0.0)
	side_box.add_child(_info)
	var hint := Label.new()
	hint.text = "Click a system to plot a route.\nClose the map, then J to jump.\nM or Esc closes."
	hint.modulate = Color(1, 1, 1, 0.6)
	side_box.add_child(hint)


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	refresh()


func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if DebugCommands.console_open:
		return
	if event.is_action_pressed(&"galaxy_map", false, true) or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Selects `system_id` and plots a route to it (also used by tests).
## Returns false if the system can't be reached.
func select(system_id: String) -> bool:
	selected = system_id
	var ok: bool = hyperspace.plot_to(system_id)
	refresh()
	return ok


func refresh() -> void:
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var travel: TravelState = GameState.travel
	var explored: bool = travel.map_state(galaxy, selected) == "explored"
	var system: SystemDef = DataRegistry.get_system(selected)
	_title.text = system.name if explored and system != null else "Unexplored system"
	var lines: Array[String] = []
	if explored and system != null:
		var gov: GovernmentDef = DataRegistry.get_government(system.government())
		lines.append("Government: %s" % (gov.name if gov != null else "none"))
		var ports: int = system.objects.filter(func(o: SystemObjectDef) -> bool: return o.landable).size()
		lines.append("%d place%s to land" % [ports, "" if ports == 1 else "s"])
	else:
		lines.append("No survey data until you visit.")
	lines.append("")
	if selected == travel.current_system:
		lines.append("You are here.")
	elif not travel.route.is_empty() and travel.route[-1] == selected:
		var player: Ship = get_tree().get_first_node_in_group(&"player")
		var cost: Dictionary = Hyperlanes.route_cost(galaxy, travel.current_system, travel.route, player.def.jump_speed, player.def.jump_fuel)
		lines.append("Route: %d jump%s, %d day%s, %.0f fuel (you have %.0f)" % [cost["jumps"], "" if cost["jumps"] == 1 else "s",
			cost["days"], "" if cost["days"] == 1 else "s", cost["fuel"], travel.fuel])
		if cost["fuel"] > travel.fuel + 0.0001:
			lines.append("Not enough fuel for the whole route: refuel on the way.")
	else:
		lines.append("No known route.")
	_info.text = "\n".join(lines)
	if system != null:
		for o: SystemObjectDef in system.objects:
			StellarArt.icon(o.art)  # load before drawing
	_map.queue_redraw()
	_view.queue_redraw()


## Visible system ids and their screen positions on the map control.
func _screen_points() -> Dictionary:
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var hidden: Dictionary = GameState.travel.hidden_set(galaxy)
	var ids: Array[String] = []
	var points: Array[Vector2] = []
	for id: String in galaxy.system_ids:
		if not hidden.has(id):
			ids.append(id)
			points.append(galaxy.positions[id])
	var transform: Transform2D = MapLayout.fit(points, Rect2(Vector2.ZERO, _map.size), MAP_MARGIN)
	var result: Dictionary = {}
	for i: int in ids.size():
		result[ids[i]] = transform * points[i]
	return result


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen: Dictionary = _screen_points()
		var ids: Array[String] = []
		ids.assign(screen.keys())
		var points: Array[Vector2] = []
		points.assign(screen.values())
		var index: int = MapLayout.pick(points, event.position, PICK_RADIUS)
		if index >= 0:
			select(ids[index])
			_map.accept_event()


func _draw_map() -> void:
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var travel: TravelState = GameState.travel
	var screen: Dictionary = _screen_points()
	var font: Font = ThemeDB.fallback_font
	var route_pairs: Dictionary = {}
	var at: String = travel.current_system
	for next: String in travel.route:
		route_pairs[_pair(at, next)] = true
		at = next
	for lane: Dictionary in galaxy.lanes:
		if not screen.has(lane["from"]) or not screen.has(lane["to"]):
			continue
		var on_route: bool = route_pairs.has(_pair(lane["from"], lane["to"]))
		_map.draw_line(screen[lane["from"]], screen[lane["to"]],
			Color.html(_colours["route"] if on_route else _colours["lane"]), 3.0 if on_route else 1.5, true)
	# TR7: gate links, dashed; dimmed while either gate is closed (TR6).
	for link: Dictionary in galaxy.gate_links:
		if not screen.has(link["from"]) or not screen.has(link["to"]):
			continue
		var colour := Color.html(_colours["gate_link"])
		if not (_gate_open(link["from"]) and _gate_open(link["to"])):
			colour.a *= 0.3
		_map.draw_dashed_line(screen[link["from"]], screen[link["to"]], colour, 2.0, 8.0, true, true)
	for id: String in screen:
		var p: Vector2 = screen[id]
		var explored: bool = travel.map_state(galaxy, id) == "explored"
		var system: SystemDef = DataRegistry.get_system(id)
		if explored:
			var gov: GovernmentDef = DataRegistry.get_government(system.government())
			_map.draw_circle(p, DOT_RADIUS, gov.colour if gov != null else Color.html(_colours["label"]))
		else:
			_map.draw_arc(p, DOT_RADIUS, 0.0, TAU, 24, Color.html(_colours["unexplored"]), 2.0, true)
		if id == travel.current_system:
			_map.draw_arc(p, DOT_RADIUS + 5.0, 0.0, TAU, 32, Color.html(_colours["current"]), 2.0, true)
		if id == selected:
			_map.draw_arc(p, DOT_RADIUS + 9.0, 0.0, TAU, 32, Color.html(_colours["selected"]), 2.0, true)
		var label: String = system.name if explored else "Unexplored"
		var colour: Color = Color.html(_colours["label"] if explored else _colours["unexplored"])
		var label_at: Vector2 = p + Vector2(-80.0, DOT_RADIUS + 22.0)
		_map.draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, FONT_SIZE, 6, Color.html(_colours["background"]))
		_map.draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, FONT_SIZE, colour)


## The selected system, laid out from its data: star, planets, stations,
## which can be landed on, and the jump radius.
func _draw_view() -> void:
	var size: float = _view.size.x
	var centre := Vector2(size, size) / 2.0
	_view.draw_rect(Rect2(Vector2.ZERO, Vector2(size, size)), Color(1, 1, 1, 0.04))
	var font: Font = ThemeDB.fallback_font
	var system: SystemDef = DataRegistry.get_system(selected)
	if system == null or GameState.travel.map_state(DataRegistry.galaxy(), selected) != "explored":
		_view.draw_string(font, centre + Vector2(-size / 2.0, 0.0), "No survey data", HORIZONTAL_ALIGNMENT_CENTER, size, FONT_SIZE,
			Color.html(_colours["unexplored"]))
		return
	var scale: float = MapLayout.system_scale(system, size * 0.92)
	var jump_colour := Color.html(_colours["jump_radius"])
	var dashes: int = 48
	for i: int in dashes:
		if i % 2 == 0:
			_view.draw_arc(centre, system.jump_radius * scale, TAU * i / dashes, TAU * (i + 1) / dashes, 4, jump_colour, 1.0, true)
	for o: SystemObjectDef in system.objects:
		var p: Vector2 = centre + o.position * scale
		var r: float = maxf(o.radius * scale, 3.0)
		var icon: Texture2D = StellarArt.icon(o.art)
		if icon != null:
			# The art's 64 px map icon, sized to the stellar (stars and planets
			# by radius, stations and gates a fixed small size).
			r = clampf(o.radius * scale, 7.0, 22.0) if o.type == "star" or o.type == "planet" else ICON_SMALL / 2.0
			var tint: Color = o.colour if o.type == "star" else Color.WHITE
			_view.draw_texture_rect(icon, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)
			if o.landable or o.type == "gate":
				_view.draw_arc(p, r + 4.0, 0.0, TAU, 24, Color.html(_colours["label"]), 1.0, true)
			if o.type != "star":
				_view.draw_string(font, p + Vector2(r + 7.0, 5.0), o.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2,
					Color.html(_colours["label"]))
			continue
		match o.type:
			"star":
				r = maxf(r, 7.0)
				_view.draw_circle(p, r * 2.0, Color(o.colour, 0.15))
				_view.draw_circle(p, r, o.colour)
			"station":
				_view.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), o.colour)
				r = 6.0
			"gate":
				r = 6.0
				_view.draw_arc(p, r, 0.0, TAU, 24, Color.html(_colours["gate_link"]), 2.5, true)
			_:
				_view.draw_circle(p, r, o.colour)
		if o.landable or o.type == "gate":
			_view.draw_arc(p, r + 4.0, 0.0, TAU, 24, Color.html(_colours["label"]), 1.0, true)
		if o.type != "star":
			_view.draw_string(font, p + Vector2(r + 7.0, 5.0), o.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2,
				Color.html(_colours["label"]))


static func _gate_open(system_id: String) -> bool:
	var system: SystemDef = DataRegistry.get_system(system_id)
	var gate: SystemObjectDef = system.gate() if system != null else null
	return gate != null and GateRules.is_open(gate.open_condition, GameState.flags)


static func _pair(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])
