extends Node
## Holds every definition after loading data/ then mods/ (later files with the
## same ID win). If anything is invalid the game refuses to start and lists
## each error with its file and field. reload() supports D8 hot reload.

signal data_reloaded

const ROOTS: Array[String] = ["res://data", "res://mods"]

var settings: Dictionary = {}
## Errors from the startup load. Non-empty means the game must not start.
var load_errors: Array[String] = []
var _set: DataSet = DataSet.new()


func _ready() -> void:
	var loaded: DataSet = DataLoader.load_roots(ROOTS)
	load_errors = loaded.errors
	if not load_errors.is_empty():
		push_error("Data errors (%d), the game cannot start:\n%s" % [load_errors.size(), "\n".join(load_errors)])
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	_apply(loaded)


## D8: re-reads every file. On success swaps in the new data and emits
## data_reloaded; on failure keeps the current data and returns the errors.
func reload() -> Array[String]:
	var loaded: DataSet = DataLoader.load_roots(ROOTS)
	if not loaded.errors.is_empty():
		push_error("Reload failed, keeping previous data:\n%s" % "\n".join(loaded.errors))
		return loaded.errors
	_apply(loaded)
	data_reloaded.emit()
	return []


func get_ship(id: String) -> ShipDef:
	return _set.get_def("ships", id)


func get_weapon(id: String) -> WeaponDef:
	return _set.get_def("weapons", id)


func get_government(id: String) -> GovernmentDef:
	return _set.get_def("governments", id)


func get_ai_pool(id: String) -> AiPoolDef:
	return _set.get_def("ai_pools", id)


func get_system(id: String) -> SystemDef:
	return _set.get_def("systems", id)


func get_scenery(id: String) -> SceneryDef:
	return _set.get_def("scenery", id)


func get_personality(id: String) -> PersonalityDef:
	return _set.get_def("personalities", id)


func get_galaxy(id: String) -> GalaxyDef:
	return _set.get_def("galaxy", id)


## TR1: the galaxy game.json names.
func galaxy() -> GalaxyDef:
	return get_galaxy(settings.get("galaxy", ""))


## Sorted IDs of one type folder ("ships", "systems"…).
func ids(type: String) -> Array[String]:
	return _set.ids(type)


func _apply(loaded: DataSet) -> void:
	_set = loaded
	settings = loaded.settings
	for line: String in loaded.overrides:
		print("Mod override: ", line)
