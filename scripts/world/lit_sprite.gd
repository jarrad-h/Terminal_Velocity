class_name LitSprite
extends RefCounted
## V6: sprites lit live from their light maps (docs/art/lighting.md). A sprite
## at `<name>.png` with `<name>_albedo.png` and `<name>_n.png` beside it is
## drawn as a CanvasTexture (albedo + normal) so the star and point lights
## shade it; `<name>_e.png`, if present, is an additive, unshaded child. A
## sprite without maps falls back to its baked image, drawn unshaded so the
## ambient light doesn't darken it.

static var _unshaded: CanvasItemMaterial = null
static var _emissive: CanvasItemMaterial = null


## Shared material for anything drawn at full brightness (no maps): dust,
## shots, flashes, labels, placeholders.
static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Additive and unshaded: emission layers, glows.
static func emissive_material() -> CanvasItemMaterial:
	if _emissive == null:
		_emissive = CanvasItemMaterial.new()
		_emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_emissive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _emissive


## `<name>_<suffix>.png` beside `path` ("res://…/<name>.png").
static func map_path(path: String, suffix: String) -> String:
	return "%s_%s.png" % [path.get_basename(), suffix]


static func has_maps(path: String) -> bool:
	return ResourceLoader.exists(map_path(path, "albedo")) and ResourceLoader.exists(map_path(path, "n"))


## A Sprite2D for the image at `path` (res:// path to the baked `.png`):
## lit when it has maps, else the baked image unshaded.
static func build(path: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	if has_maps(path):
		var texture := CanvasTexture.new()
		texture.diffuse_texture = load(map_path(path, "albedo"))
		texture.normal_texture = load(map_path(path, "n"))
		sprite.texture = texture
		var glow_path: String = map_path(path, "e")
		if ResourceLoader.exists(glow_path):
			var glow := Sprite2D.new()
			glow.name = "Emission"
			glow.texture = load(glow_path)
			glow.material = emissive_material()
			sprite.add_child(glow)
	else:
		sprite.texture = load(path)
		sprite.material = unshaded_material()
	return sprite
