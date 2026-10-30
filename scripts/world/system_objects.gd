class_name SystemObjects
extends Node2D
## S1, V9: the system's star, planets, stations and gates from the system file.
## Each stellar with an `art` set is drawn from it (StellarArt; lit where the
## art has maps); the rest as flat placeholder circles. Names are drawn on top.
## Clouds turn slowly, city lights follow the night side, and a closed gate
## (TR6) hides its ring.

const LABEL_SIZE: int = 16
const LABEL_COLOUR := Color(0.85, 0.9, 1.0, 0.9)

var system: SystemDef = null
var _views: Dictionary = {}  # object id -> Node2D
var _labels: Node2D


func _init() -> void:
	material = LitSprite.unshaded_material()  # V6: placeholders at full brightness, not lit or darkened


func _ready() -> void:
	GameState.flags_changed.connect(_update_gates)


func configure(p_system: SystemDef) -> void:
	system = p_system
	for view: Node in _views.values():
		view.queue_free()
	_views.clear()
	if _labels != null:
		_labels.queue_free()
	var settings: Dictionary = DataRegistry.settings["stellars"]
	for obj: SystemObjectDef in system.objects:
		if obj.art != "":
			var view: Node2D = StellarArt.build(obj, settings)
			add_child(view)
			_views[obj.id] = view
	_labels = Node2D.new()
	_labels.name = "Labels"
	_labels.material = LitSprite.unshaded_material()
	_labels.draw.connect(_draw_labels)
	add_child(_labels)
	_update_gates()
	queue_redraw()


## The drawn node for a stellar, or null (placeholder or none).
func view_of(object_id: String) -> Node2D:
	return _views.get(object_id)


func _update_gates() -> void:
	if system == null:
		return
	for obj: SystemObjectDef in system.objects:
		var view: Node2D = _views.get(obj.id)
		if obj.type == "gate" and view != null and view.has_node("Ring"):
			view.get_node("Ring").visible = GateRules.is_open(obj.open_condition, GameState.flags)
	queue_redraw()


func _process(delta: float) -> void:
	if _views.is_empty():
		return
	var spin: float = deg_to_rad(float(DataRegistry.settings["stellars"]["cloud_spin"])) * delta
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var lighting: SystemLighting = scene.lighting if scene != null else null
	for view: Node2D in _views.values():
		var clouds: Node2D = view.get_node_or_null("Clouds")
		if clouds != null:
			clouds.rotation += spin
		var glow: Sprite2D = view.get_node_or_null("Emission")
		if glow != null and glow.material is ShaderMaterial and lighting != null:
			var night: ShaderMaterial = glow.material
			night.set_shader_parameter("light_to_star", -lighting.light_direction().rotated(-view.global_rotation))
			night.set_shader_parameter("light_height", lighting.star_light.height)


func _draw() -> void:
	if system == null:
		return
	for obj: SystemObjectDef in system.objects:
		if obj.art != "":
			continue
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


func _draw_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	for obj: SystemObjectDef in system.objects:
		_labels.draw_string(font, obj.position + Vector2(-150.0, obj.radius + 24.0), obj.name, HORIZONTAL_ALIGNMENT_CENTER, 300.0, LABEL_SIZE, LABEL_COLOUR)
