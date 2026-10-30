class_name DynamicLights
extends RefCounted
## V8: short-lived point lights from weapon fire and impacts, and dim lights
## at engine exits, so nearby lit hulls (V6) catch them. Values come from
## game.json lighting (shot, impact, engine). Shot and impact lights share a
## cap on how many burn at once, so heavy fire costs no more than the cap.

const GROUP: StringName = &"dynamic_lights"
const TEXTURE_SIZE: int = 128

static var _texture: GradientTexture2D = null
static var _active: int = 0


## A soft round light texture shared by every point light.
static func texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
	return _texture


static func lighting_on(tree: SceneTree) -> bool:
	var scene: Node = tree.get_first_node_in_group(&"system_scene")
	return scene != null and scene.lighting != null and scene.lighting.enabled


## A point light with `settings` ({"energy", "radius", "height"}) in `colour`.
static func make(colour: Color, settings: Dictionary) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = texture()
	light.color = colour
	light.energy = float(settings["energy"])
	light.texture_scale = float(settings["radius"]) * 2.0 / TEXTURE_SIZE
	light.height = float(settings["height"])
	light.add_to_group(GROUP)
	return light


## V8: lights a shot or beam (`owner_node`) while it exists, if lighting is
## on and the cap allows. Returns the light (a child of `owner_node`) or null.
static func attach(owner_node: Node2D, colour: Color, kind: String) -> PointLight2D:
	var settings: Dictionary = DataRegistry.settings["lighting"]
	if not lighting_on(owner_node.get_tree()) or _active >= int(settings["max_lights"]):
		return null
	var light: PointLight2D = make(colour, settings[kind])
	_active += 1
	light.tree_exiting.connect(func() -> void: _active -= 1)
	owner_node.add_child(light)
	return light


## V8: a light at an impact that fades out over the impact's duration.
static func impact(parent: Node, at: Vector2, colour: Color) -> void:
	var settings: Dictionary = DataRegistry.settings["lighting"]
	if not lighting_on(parent.get_tree()) or _active >= int(settings["max_lights"]):
		return
	var light: PointLight2D = make(colour, settings["impact"])
	_active += 1
	light.tree_exiting.connect(func() -> void: _active -= 1)
	light.position = at
	parent.add_child(light)
	var fade: Tween = light.create_tween()
	fade.tween_property(light, "energy", 0.0, float(settings["impact"]["duration"]))
	fade.tween_callback(light.queue_free)


## Lights currently counted against the cap (shots, beams, impacts).
static func active_count() -> int:
	return _active


## D14: switches every dynamic light on or off.
static func set_all_enabled(tree: SceneTree, enabled: bool) -> void:
	for node: Node in tree.get_nodes_in_group(GROUP):
		(node as PointLight2D).enabled = enabled
