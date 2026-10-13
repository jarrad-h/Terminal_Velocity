extends Node
## Loads JSON definitions from data/. Milestone 1 version: global settings and
## ships by ID only. Validation, other types and mod overrides arrive in
## milestone 2.

const DATA_DIR: String = "res://data"

## Documented in data/README.md; keep the two in sync.
const SETTINGS_DEFAULTS: Dictionary = {
	"player_ship": "courier",
	"background_colour": "#05060c",
	"camera": {"zoom": 1.0, "smoothing_speed": 0.0},
	"starfield": {"seed": 1, "tile_size": 2048.0, "layers": [
		{"scroll_scale": 0.15, "count": 400, "size": 1.0, "brightness": 0.35},
		{"scroll_scale": 0.4, "count": 200, "size": 1.5, "brightness": 0.6},
		{"scroll_scale": 0.8, "count": 80, "size": 2.0, "brightness": 0.9},
	]},
	"debug": {"time_scales": [0.25, 0.5, 1.0, 2.0, 4.0], "velocity_vector_seconds": 0.5},
}
const SHIP_DEFAULTS: Dictionary = {"hit_radius": 16.0, "sprite": ""}
const SHIP_REQUIRED: Array[String] = ["accel", "top_speed", "turn_rate"]

var settings: Dictionary = {}


func _ready() -> void:
	settings = _merged(SETTINGS_DEFAULTS, _load_json("%s/game.json" % DATA_DIR))


## Returns the ship definition with defaults filled in, or {} if it is missing
## or invalid (the error names the file and field).
func get_ship(id: String) -> Dictionary:
	var path: String = "%s/ships/%s.json" % [DATA_DIR, id]
	var def: Dictionary = _load_json(path)
	if def.is_empty():
		return {}
	for field: String in SHIP_REQUIRED:
		if not def.has(field):
			push_error("%s: missing required field '%s'" % [path, field])
			return {}
	return _merged(SHIP_DEFAULTS, def)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("%s: file not found" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("%s: not a JSON object (check for syntax errors)" % path)
		return {}
	return parsed


## Recursively overlays `over` on `base`; nested dictionaries merge key by key.
func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in over:
		if result.get(key) is Dictionary and over[key] is Dictionary:
			result[key] = _merged(result[key], over[key])
		else:
			result[key] = over[key]
	return result
