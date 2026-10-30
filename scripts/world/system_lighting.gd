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
var _settings: Dictionary = {}


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
			break
	star_light.color = _settings["star_colour"]
	star_light.energy = _settings["star_energy"]
	star_light.height = _settings["star_height"]
	_apply_enabled()


## {"star_colour", "star_energy", "star_height", "ambient"} for `system`.
static func settings_for(system: SystemDef, defaults: Dictionary) -> Dictionary:
	var star: Dictionary = defaults["star"]
	var over: Dictionary = system.lighting
	var over_star: Dictionary = over.get("star", {})
	return {
		"star_colour": Color.html(over_star.get("colour", star["colour"])),
		"star_energy": float(over_star.get("energy", star["energy"])),
		"star_height": float(over_star.get("height", star["height"])),
		"ambient": Color.html(over.get("ambient", defaults["ambient"])),
	}


func set_enabled(value: bool) -> void:
	enabled = value
	_apply_enabled()


func set_height(value: float) -> void:
	star_light.height = clampf(value, 0.0, 1.0)


func _apply_enabled() -> void:
	star_light.enabled = enabled
	ambient.color = _settings.get("ambient", Color.WHITE) if enabled else Color.WHITE


func _process(_delta: float) -> void:
	var direction: Vector2 = light_direction()
	if not direction.is_zero_approx():
		star_light.rotation = Vector2.DOWN.angle_to(direction)


## Direction the starlight travels (from the star towards the player).
func light_direction() -> Vector2:
	if angle_override != null:
		return -Vector2.from_angle(float(angle_override))
	var player: Node2D = get_tree().get_first_node_in_group(&"player")
	if _star_position == null or player == null:
		return Vector2(1.0, 1.0).normalized()  # no star: light from the top left
	return (player.global_position - (_star_position as Vector2)).normalized()
