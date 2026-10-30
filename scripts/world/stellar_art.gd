class_name StellarArt
extends RefCounted
## V9: a stellar's art set (planets, stations, gates, the star), named by the
## stellar's `art` field and described by the manifest beside its sprites in
## assets/sprites/stellars/<folder>/<art>.json (docs/art/stellars.md).
## Sprites scale so the art's disc (or full size) matches the stellar's
## radius × 2.

const ROOT: String = "res://assets/sprites/stellars"
const FOLDERS: Array[String] = ["planets", "stations", "gates", "stars"]
const NIGHT_SHADER: String = "res://assets/shaders/night_lights.gdshader"

static var _manifests: Dictionary = {}
static var _icons: Dictionary = {}


## res:// path of the art set's baked sprite (without "_layer"), or "".
static func base_path(art: String) -> String:
	for folder: String in FOLDERS:
		var json: String = ROOT.path_join(folder).path_join(art + ".json")
		if FileAccess.file_exists(json):
			return json.get_basename()
	return ""


## The art set's manifest (cached), or {} if there is none.
static func manifest(art: String) -> Dictionary:
	if not _manifests.has(art):
		var base: String = base_path(art)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json")) if base != "" else null
		_manifests[art] = data if data is Dictionary else {}
	return _manifests[art]


## Px of art that span the stellar's diameter: the disc for planets and the
## star, else the sprite's width.
static func diameter_px(art: String) -> float:
	var m: Dictionary = manifest(art)
	if m.has("disc_px"):
		return float(m["disc_px"])
	var size: Array = m.get("size_px", [1.0, 1.0])
	return float(size[0])


## TR5: where ships leave and arrive at a gate, px from its centre.
static func jump_point(gate: SystemObjectDef) -> Vector2:
	var point: Array = manifest(gate.art).get("jump_point", [0.0, 0.0]) if gate.art != "" else [0.0, 0.0]
	var scale: float = gate.radius * 2.0 / diameter_px(gate.art) if gate.art != "" else 1.0
	return Vector2(float(point[0]), float(point[1])) * scale


## The stellar drawn from its art set: a Node2D at the stellar's position.
static func build(obj: SystemObjectDef, settings: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = obj.id
	root.position = obj.position
	var base: String = base_path(obj.art) + ".png"
	root.scale = Vector2.ONE * obj.radius * 2.0 / diameter_px(obj.art)
	match obj.type:
		"star":
			var star := Sprite2D.new()
			star.texture = load(base.get_basename() + "_e.png")
			star.modulate = obj.colour
			star.material = LitSprite.emissive_material()
			star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			root.add_child(star)
		"planet":
			_build_planet(root, obj.art, base, settings)
		_:
			var body: Sprite2D = LitSprite.build(base)
			root.add_child(body)
			var ring_path: String = LitSprite.map_path(base, "e_ring")
			if obj.type == "gate" and ResourceLoader.exists(ring_path):
				var ring := Sprite2D.new()
				ring.name = "Ring"
				ring.texture = load(ring_path)
				ring.material = LitSprite.emissive_material()
				root.add_child(ring)
	return root


## Layer order (docs/art/stellars.md): rings, surface, emission, clouds, atmosphere.
static func _build_planet(root: Node2D, art: String, base: String, settings: Dictionary) -> void:
	var layers: Array = manifest(art).get("layers", [])
	if "rings" in layers:
		root.add_child(_lit_layer(LitSprite.map_path(base, "rings"), LitSprite.map_path(base, "rings_n"), "Rings"))
	root.add_child(_lit_layer(LitSprite.map_path(base, "albedo"), LitSprite.map_path(base, "n"), "Surface"))
	if "e" in layers:
		var glow := Sprite2D.new()
		glow.name = "Emission"
		glow.texture = load(LitSprite.map_path(base, "e"))
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if art in settings["night_only_emission"]:
			var night := ShaderMaterial.new()
			night.shader = load(NIGHT_SHADER)
			night.set_shader_parameter("normal_map", load(LitSprite.map_path(base, "n")))
			glow.material = night
		else:
			glow.material = LitSprite.emissive_material()
		root.add_child(glow)
	if "clouds" in layers:
		var clouds: Sprite2D = _lit_layer(LitSprite.map_path(base, "clouds"), LitSprite.map_path(base, "clouds_n"), "Clouds")
		root.add_child(clouds)
	if "atmo" in layers:
		var atmo: Sprite2D = _lit_layer(LitSprite.map_path(base, "atmo"), LitSprite.map_path(base, "atmo_n"), "Atmosphere")
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		atmo.material = add
		root.add_child(atmo)


static func _lit_layer(albedo: String, normal: String, layer_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = layer_name
	var texture := CanvasTexture.new()
	texture.diffuse_texture = load(albedo)
	texture.normal_texture = load(normal)
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite


## TR7 system view icon (64 px) for the art set, or null. Cached: call it
## before drawing (a texture first loaded inside a draw call renders blank).
static func icon(art: String) -> Texture2D:
	if not _icons.has(art):
		var path: String = ROOT.path_join("icons").path_join("icon_%s.png" % art)
		_icons[art] = load(path) if art != "" and ResourceLoader.exists(path) else null
	return _icons[art]
