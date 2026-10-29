class_name TargetPanel
extends HBoxContainer
## H3: the selected target as a schematic (nose-up silhouette shaded by armour,
## shield outline fading with the shield, grey when disabled) beside its shield
## and armour readouts, class, type, government, standing (G5), distance and a
## hint. Colours come from game.json "hud" and "radar".

const SCHEMATIC_SIZE := Vector2(96.0, 120.0)
## Outline thickness of the shield glow, px.
const OUTLINE_PX: float = 2.0

var player: Ship = null
var target: Ship = null

var _schematic: Schematic
var _class: Label
var _type: Label
var _government: Label
var _standing: Label
var _distance: Label
var _hint: Label
var _shield: ProgressBar
var _armor: ProgressBar


class Schematic:
	extends Control
	var panel: TargetPanel
	var _texture_cache: Dictionary = {}

	func _ready() -> void:
		custom_minimum_size = TargetPanel.SCHEMATIC_SIZE
		var material_ := ShaderMaterial.new()
		material_.shader = preload("res://assets/shaders/silhouette.gdshader")
		material = material_

	func _texture(ship: Ship) -> Texture2D:
		var path: String = Ship.SPRITE_DIR.path_join(ship.def.sprite)
		if ship.def.sprite == "" or not ResourceLoader.exists(path):
			return null
		if not _texture_cache.has(path):
			_texture_cache[path] = load(path)
		return _texture_cache[path]

	func _draw() -> void:
		var ship: Ship = panel.target
		if ship == null or not is_instance_valid(ship):
			return
		var colours: Dictionary = DataRegistry.settings["hud"]["colours"]
		var fill: Color = Color.html(colours["schematic_disabled"])
		if not ship.health.is_disabled:
			fill = HudMath.health_colour(ship.health.armor / maxf(ship.health.max_armor, 0.001),
				Color.html(colours["schematic_full"]), Color.html(colours["schematic_half"]), Color.html(colours["schematic_empty"]))
		var shield_fraction: float = ship.health.shield / ship.health.max_shield if ship.health.max_shield > 0.0 else 0.0
		var glow := Color(Color.html(colours["shield"]), 0.9 * shield_fraction)
		var texture: Texture2D = _texture(ship)
		var art: Vector2 = texture.get_size() if texture != null else ship.def.hit_size
		var box: Vector2 = size - Vector2.ONE * (TargetPanel.OUTLINE_PX * 2.0 + 2.0)
		var draw_size: Vector2 = art * HudMath.fit_scale(art, box, 2.0)
		var rect := Rect2((size - draw_size) / 2.0, draw_size)
		var offsets: Array[Vector2] = []
		for i: int in 8:
			offsets.append(Vector2.RIGHT.rotated(TAU * i / 8.0) * TargetPanel.OUTLINE_PX)
		if glow.a > 0.0:
			for o: Vector2 in offsets:
				_shape(texture, Rect2(rect.position + o, rect.size), glow)
		_shape(texture, rect, fill)

	## The hull: its sprite, or the placeholder arrow when it has none.
	func _shape(texture: Texture2D, rect: Rect2, colour: Color) -> void:
		if texture != null:
			draw_texture_rect(texture, rect, false, colour)
			return
		var c: Vector2 = rect.get_center()
		var w: float = rect.size.x / 2.0
		var l: float = rect.size.y / 2.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -l), c + Vector2(w * 0.7, l * 0.8),
			c + Vector2(0.0, l * 0.4), c + Vector2(-w * 0.7, l * 0.8)]), colour)


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_schematic = Schematic.new()
	_schematic.panel = self
	add_child(_schematic)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	add_child(info)
	_class = _label(info)
	_type = _label(info)
	_government = _label(info)
	_standing = _label(info)
	_shield = Hud.make_bar(info, "Shield", Color.html(DataRegistry.settings["hud"]["colours"]["shield"]), 150.0)
	_armor = Hud.make_bar(info, "Armour", Color.html(DataRegistry.settings["hud"]["colours"]["armor"]), 150.0)
	_distance = _label(info)
	_hint = _label(info)


func _label(parent: Control) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label


func refresh() -> void:
	visible = target != null and is_instance_valid(target) and player != null
	if not visible:
		return
	_class.text = target.def.name
	_type.text = target.role.capitalize() if target.role != "" else "No role"
	var gov: GovernmentDef = target.gov_def()
	_government.text = gov.name if gov != null else "No government"
	var standing: String = target.standing_to(player)
	_standing.text = standing.capitalize()
	_standing.add_theme_color_override("font_color", Color.html(DataRegistry.settings["radar"]["colours"][Radar.standing_colour_key(standing)]))
	Hud.fill_bar(_shield, target.health.shield, target.health.max_shield)
	Hud.fill_bar(_armor, target.health.armor, target.health.max_armor)
	_distance.text = "%.0f px away" % target.global_position.distance_to(player.global_position)
	_hint.text = "Disabled: B to board" if target.health.is_disabled else ""
	_schematic.queue_redraw()
