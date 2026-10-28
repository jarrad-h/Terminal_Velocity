class_name DataLoader
extends RefCounted
## Loads every definition type from a list of root folders in order
## (normally data/ then mods/). A later file with the same ID replaces the
## earlier one. After loading, every reference is resolved; problems are
## collected as errors naming the file and field, never thrown.

## Definition type folders, in load order.
const TYPES: Array[String] = ["ships", "weapons", "governments", "ai_pools", "systems", "scenery", "personalities"]

const SETTINGS_FILE: String = "game.json"

## Global settings defaults; documented in data/README.md.
const SETTINGS_DEFAULTS: Dictionary = {
	"player_ship": "courier",
	"system": "test_nebula",
	"camera": {"zoom": 1.0, "smoothing_speed": 0.0},
	"player": {"credits": 0, "record": 0.0},
	"combat": {"friendly_fire_pct": 100.0},
	"local_space": {"chunk_size": 1024.0},
	"ai": {"landing_speed": 60.0, "land_radius_fraction": 0.6, "thrust_angle": 35.0,
		"standoff_fraction": 0.4, "think_interval": 0.25, "disengage_factor": 1.5,
		"waypoint_reached_fraction": 0.1, "object_patrol_chance": 0.6, "object_patrol_offset_factor": 0.3,
		"roam_band": [0.1, 0.6], "jump_out_factor": 1.05, "planet_spawn_chance": 0.5,
		"arrival_speed_fraction": 0.5, "spawn_keep_away_factor": 1.2, "inside_spawn_band": [0.15, 0.7]},
	"radar": {"size": 200.0, "range": 3000.0, "margin": 16.0, "colours": {
		"background": "#0a1426c0", "rim": "#5a7aa0", "player": "#ffffff",
		"neutral": "#b0b0b0", "target": "#ffee40", "scenery": "#8a7a68",
		"hostile": "#ff4040", "friendly": "#40d080", "warned": "#ffb030"}},
	"debug": {"time_scales": [0.25, 0.5, 1.0, 2.0, 4.0], "velocity_vector_seconds": 0.5,
		"spawn_distance": 350.0, "spawn_at_start": []},
}


static func load_roots(roots: Array[String]) -> DataSet:
	var data_set := DataSet.new()
	var refs: Array[Dictionary] = []
	for type: String in TYPES:
		data_set.defs[type] = {}
	data_set.settings = SETTINGS_DEFAULTS.duplicate(true)

	for root: String in roots:
		var settings_path: String = root.path_join(SETTINGS_FILE)
		if FileAccess.file_exists(settings_path):
			var raw: Variant = _read_json(settings_path, data_set.errors)
			if raw is Dictionary:
				data_set.settings = _merged(data_set.settings, raw)
		for type: String in TYPES:
			for path: String in _json_files(root.path_join(type)):
				_load_def(data_set, type, path, refs)

	_check_settings(data_set, refs)
	for r: Dictionary in refs:
		if not data_set.defs[r["type"]].has(r["id"]):
			data_set.errors.append("%s: no %s definition with id '%s'" % [r["field"], _singular(r["type"]), r["id"]])
	for type: String in TYPES:
		for def: Def in data_set.defs[type].values():
			def.validate(data_set.defs, data_set.errors)
	return data_set


static func _load_def(data_set: DataSet, type: String, path: String, refs: Array[Dictionary]) -> void:
	var raw: Variant = _read_json(path, data_set.errors)
	if not raw is Dictionary:
		return
	var id: String = path.get_file().get_basename()
	if raw.has("id") and raw["id"] != id:
		data_set.errors.append("%s: field 'id': '%s' does not match the file name (expected '%s')" % [path, raw["id"], id])
		return
	var errors_before: int = data_set.errors.size()
	var reader := DefReader.new(raw, path, data_set.errors)
	reader.string("id")
	var def: Def = _parse(type, reader)
	reader.finish()
	if data_set.errors.size() > errors_before:
		# Not registered, but still report its broken references in the same pass.
		refs.append_array(reader.refs)
		return
	def.id = id
	def.file = path
	if data_set.defs[type].has(id):
		data_set.overrides.append("%s replaces %s" % [path, data_set.defs[type][id].file])
		# Drop references recorded by the replaced file.
		for i: int in range(refs.size() - 1, -1, -1):
			if refs[i]["field"].begins_with(data_set.defs[type][id].file + ":"):
				refs.remove_at(i)
	data_set.defs[type][id] = def
	refs.append_array(reader.refs)


static func _parse(type: String, reader: DefReader) -> Def:
	match type:
		"ships":
			return ShipDef.parse(reader)
		"weapons":
			return WeaponDef.parse(reader)
		"governments":
			return GovernmentDef.parse(reader)
		"ai_pools":
			return AiPoolDef.parse(reader)
		"systems":
			return SystemDef.parse(reader)
		"scenery":
			return SceneryDef.parse(reader)
		"personalities":
			return PersonalityDef.parse(reader)
	assert(false, "unknown definition type " + type)
	return null


static func _check_settings(data_set: DataSet, refs: Array[Dictionary]) -> void:
	var errors: Array[String] = []
	var reader := DefReader.new(data_set.settings, SETTINGS_FILE, errors)
	reader.ref("player_ship", "ships")
	reader.ref("system", "systems")
	reader.object("player").number("credits", 0.0)
	reader.object("player").number("record", 0.0)
	reader.object("combat").number("friendly_fire_pct", 100.0, false, 0.0)
	var ai: DefReader = reader.object("ai")
	for key: String in SETTINGS_DEFAULTS["ai"]:
		if SETTINGS_DEFAULTS["ai"][key] is Array:
			ai.range2(key, Vector2.ZERO, 0.0)
		else:
			# Leaving ships must aim beyond the edge, or they'd never jump out.
			ai.number(key, 0.0, false, 1.0 if key == "jump_out_factor" else 0.0)
	var radar: DefReader = reader.object("radar")
	for key: String in ["size", "range", "margin"]:
		radar.number(key, 0.0, false, 0.0)
	var colours: DefReader = radar.object("colours")
	for key: String in SETTINGS_DEFAULTS["radar"]["colours"]:
		colours.colour(key)
	for spawn: DefReader in reader.object("debug").objects("spawn_at_start"):
		spawn.ref("ship", "ships", "", true)
		spawn.ref("government", "governments")
		spawn.vec2("position", Vector2.ZERO)
	refs.append_array(reader.refs)
	data_set.errors.append_array(errors)


static func _json_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "json":
			result.append(dir_path.path_join(file))
	result.sort()
	return result


static func _read_json(path: String, errors: Array[String]) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s: line %d: invalid JSON: %s" % [path, json.get_error_line() + 1, json.get_error_message()])
		return null
	if not json.data is Dictionary:
		errors.append("%s: expected a JSON object {...} at the top level" % path)
		return null
	return json.data


## Recursively overlays `over` on `base`; nested dictionaries merge key by key.
static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in over:
		if result.get(key) is Dictionary and over[key] is Dictionary:
			result[key] = _merged(result[key], over[key])
		else:
			result[key] = over[key]
	return result


static func _singular(type: String) -> String:
	return {"ships": "ship", "weapons": "weapon", "governments": "government",
		"ai_pools": "AI pool", "systems": "system", "scenery": "scenery",
		"personalities": "personality"}[type]
