class_name SystemLighting
extends Node2D
## V7: the system's star is the key light and its ambient level darkens the
## unlit side. A DirectionalLight2D aimed from the star towards the player
## (updated each frame) and a CanvasModulate on the world layer; values come
## from game.json lighting, overridden per system. The backdrop and HUD sit on
## their own canvas layers, so neither is lit nor darkened. D14: on/off and a
## live star angle and height override.

var star_light := DirectionalLight2D.new()
var ambient := CanvasModulate.new()
var enabled: bool = true
## D14: when set, the light comes from this screen angle (radians, 0 = from
## the right) instead of from the star.
var angle_override: Variant = null
var _star_position: Variant = null
var _star_radius: float = 1.0
var _settings: Dictionary = {}
## D14: base star height (before glare lifts it towards overhead).
var _height: float = 0.3


func _ready() -> void:
	star_light.name = "StarLight"
	add_child(star_light)
	ambient.name = "Ambient"
	add_child(ambient)


## Applies the system's lighting (game.json defaults, system overrides).
func configure(system: SystemDef) -> void:
	_settings = SystemLighting.settings_for(system, DataRegistry.settings["lighting"])
	_star_position = null
	for o: SystemObjectDef in system.objects:
		if o.type == "star":
			_star_position = o.position
			_star_radius = o.radius
			break
	star_light.color = _settings["star_colour"]
	star_light.energy = _settings["star_energy"]
	_height = _settings["star_height"]
	star_light.height = _height
	_apply_enabled()


## {"star_colour", "star_energy", "star_height", "ambient"} for `system`. The
## colour is the system's override, else game.json's, else (game.json colour
## "") the star stellar's colour tinted towards white.
static func settings_for(system: SystemDef, defaults: Dictionary) -> Dictionary:
	var star: Dictionary = defaults["star"]
	var over: Dictionary = system.lighting
	var over_star: Dictionary = over.get("star", {})
	var colour: Color = Color.WHITE
	if over_star.has("colour"):
		colour = Color.html(over_star["colour"])
	elif String(star["colour"]) != "":
		colour = Color.html(star["colour"])
	else:
		for o: SystemObjectDef in system.objects:
			if o.type == "star":
				colour = StarLight.tinted(o.colour, float(star["tint"]))
				break
	return {
		"star_colour": colour,
		"star_energy": float(over_star.get("energy", star["energy"])),
		"star_height": float(over_star.get("height", star["height"])),
		"ambient": Color.html(over.get("ambient", defaults["ambient"])),
	}


func set_enabled(value: bool) -> void:
	enabled = value
	_apply_enabled()
	DynamicLights.set_all_enabled(get_tree(), value)  # V8 lights follow (D14)


func set_height(value: float) -> void:
	_height = clampf(value, 0.0, 1.0)
	star_light.height = _height


func _apply_enabled() -> void:
	star_light.enabled = enabled
	ambient.color = _settings.get("ambient", Color.WHITE) if enabled else Color.WHITE


func _process(_delta: float) -> void:
	var direction: Vector2 = light_direction()
	if not direction.is_zero_approx():
		star_light.rotation = Vector2.DOWN.angle_to(direction)
	_apply_distance()


## V7: nearer the star, stronger light; within glare range the light turns
## overhead and the ambient brightens, so inside the star nothing is in shadow.
func _apply_distance() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(&"player")
	if not enabled or _star_position == null or player == null or _settings.is_empty():
		return
	var star: Dictionary = DataRegistry.settings["lighting"]["star"]
	var distance: float = player.global_position.distance_to(_star_position)
	var glare: float = StarLight.glare(distance, _star_radius, float(star["glare_start_radii"]))
	# In the glare the ambient carries the light (evenly, in the star's hue),
	# so the directional part fades to keep the hull from blowing out.
	star_light.energy = _settings["star_energy"] * StarLight.energy_factor(distance, _star_radius,
		float(star["near_factor"]), float(star["far_factor"]), float(star["far_radii"])) \
		* lerpf(1.0, float(star["glare_energy"]), glare)
	star_light.height = lerpf(_height, 1.0, glare)
	ambient.color = (_settings["ambient"] as Color).lerp(_settings["star_colour"], glare)


## 0–1 glare at the player now (D14 readout, tests).
func glare_now() -> float:
	var player: Node2D = get_tree().get_first_node_in_group(&"player")
	if _star_position == null or player == null:
		return 0.0
	return StarLight.glare(player.global_position.distance_to(_star_position), _star_radius,
		float(DataRegistry.settings["lighting"]["star"]["glare_start_radii"]))


## Direction the starlight travels (from the star towards the player).
func light_direction() -> Vector2:
	if angle_override != null:
		return -Vector2.from_angle(float(angle_override))
	var player: Node2D = get_tree().get_first_node_in_group(&"player")
	if _star_position == null or player == null:
		return Vector2(1.0, 1.0).normalized()  # no star: light from the top left
	return (player.global_position - (_star_position as Vector2)).normalized()
