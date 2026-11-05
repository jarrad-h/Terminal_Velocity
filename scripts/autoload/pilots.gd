extends Node
## SV1–SV4: pilots and their save files on disk, and moving the live game in
## and out of them. The file format and the rules live in PilotSave (pure).
##
## Layout under `root` (game.json saves.root, default user://pilots):
##   <pilot id>/pilot.json        the pilot block (name, ironman, dead…)
##   <pilot id>/<slot id>.json    one full save per slot

signal saved(slot: String)

const SYSTEM_SCENE: String = "res://scenes/system.tscn"
const MAIN_MENU: String = "res://scenes/main_menu.tscn"

## Folder holding every pilot (tests point it elsewhere).
var root: String = ""
## The pilot playing now ("" = none: the game was started without the menu).
var pilot_id: String = ""
var pilot: Dictionary = {}
## The player block of a loaded save, applied when the system scene starts.
var pending: Dictionary = {}
## SV1: the port the player is landed at ("" = in space).
var landed_at: String = ""


func _ready() -> void:
	root = str(_settings().get("root", "user://pilots"))


## SV3: closing the window writes an ironman's slot, as quitting to the menu does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_ironman()


func _write_ironman() -> void:
	if not bool(pilot.get("ironman", false)) or bool(pilot.get("dead", false)) or not has_pilot():
		return
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	if scene == null or player == null or player.health.is_destroyed:
		return
	if landed_at == "":
		scene.leave_system()  # entities and wrecks written back first
	autosave()


func _settings() -> Dictionary:
	return DataRegistry.settings.get("saves", {})


func max_pilots() -> int:
	return int(_settings().get("max_pilots", 5))


func max_slots() -> int:
	return int(_settings().get("max_slots", 10))


func has_pilot() -> bool:
	return pilot_id != ""


# --- Pilots ------------------------------------------------------------------

## Every pilot: [{id, pilot, slots: [meta…]}], newest save first.
func list_pilots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for id: String in dir.get_directories():
		var block: Dictionary = _read_json(root.path_join(id).path_join("pilot.json"))
		if block.is_empty():
			continue
		out.append({"id": id, "pilot": block, "slots": list_slots(id)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _newest(a) > _newest(b))
	return out


func _newest(entry: Dictionary) -> String:
	var slots: Array = entry["slots"]
	return str(slots[0].get("saved_at", "")) if not slots.is_empty() else ""


## SV2, SV3: makes a new pilot and starts a new game for it. Returns "" or why not.
func create_pilot(pilot_name: String, ironman: bool) -> String:
	var existing: Array[Dictionary] = list_pilots()
	if not PilotSave.can_create_pilot(existing.size(), max_pilots()):
		return "You already have %d pilots; delete one to make room." % max_pilots()
	if pilot_name.strip_edges() == "":
		return "Your pilot needs a name."
	var ids: Array = existing.map(func(e: Dictionary) -> String: return e["id"])
	GameState.reset()
	pilot_id = PilotSave.slug(pilot_name, ids)
	pilot = PilotSave.new_pilot(pilot_name.strip_edges(), ironman, DataRegistry.settings["player"], GameState.clock.day)
	pending = {}
	landed_at = ""
	DirAccess.make_dir_recursive_absolute(root.path_join(pilot_id))
	return _write_pilot()


func delete_pilot(id: String) -> void:
	var folder: String = root.path_join(id)
	var dir := DirAccess.open(folder)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)
	DirAccess.remove_absolute(folder)
	if id == pilot_id:
		pilot_id = ""
		pilot = {}


## Without the menu (running the system scene directly, tests): an unsaved
## pilot so the game runs as before; saving asks for a real pilot.
func ensure_pilot() -> void:
	if pilot.is_empty():
		pilot = PilotSave.new_pilot("Unsaved pilot", false, DataRegistry.settings["player"], GameState.clock.day)


## SV3: an ironman pilot died with no escape: a memorial from now on.
func mark_dead() -> void:
	pilot["dead"] = true
	if has_pilot():
		_write_pilot()


func _write_pilot() -> String:
	return _write_json(root.path_join(pilot_id).path_join("pilot.json"), pilot)


# --- Slots -------------------------------------------------------------------

## A pilot's saves (meta blocks with "id" = slot id), newest first.
func list_slots(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(root.path_join(id))
	if dir == null:
		return out
	for file: String in dir.get_files():
		if not file.ends_with(".json") or file == "pilot.json":  # (.tmp files are skipped too)
			continue
		var data: Dictionary = _read_json(root.path_join(id).path_join(file))
		var meta: Dictionary = data.get("meta", {}).duplicate()
		meta["id"] = file.get_basename()
		out.append(meta)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("saved_at", "")) > str(b.get("saved_at", "")))
	return out


func manual_slots(id: String) -> Array:
	return list_slots(id).map(func(m: Dictionary) -> String: return m["id"]).filter(
		func(s: String) -> bool: return s != PilotSave.AUTOSAVE and s != PilotSave.IRONMAN)


## SV2: a manual save into slot `slot_name`. A new save never replaces an
## existing one unless `overwrite` (the Overwrite buttons). Returns "" or why not.
func save_manual(slot_name: String, overwrite: bool = false) -> String:
	if not has_pilot():
		return "No pilot to save (start from the main menu)."
	var slot: String = PilotSave.slug(slot_name) if slot_name.strip_edges() != "" else ""
	if not overwrite and manual_slots(pilot_id).has(slot):
		return "There's already a save called that: pick another name, or overwrite it."
	if not PilotSave.can_save_manual(pilot, slot, manual_slots(pilot_id), max_slots()):
		if bool(pilot.get("ironman", false)):
			return "Ironman pilots can't save by hand."
		return "All %d save slots are used: overwrite one." % max_slots() if slot != "" else "Name the save."
	return _save(slot, slot_name.strip_edges())


## SV2, SV3: the autosave (normal: landing; ironman: landing and each jump).
func autosave() -> String:
	if not has_pilot() or bool(pilot.get("dead", false)):
		return "no pilot"
	return _save(PilotSave.autosave_slot(pilot), "Autosave" if not bool(pilot.get("ironman", false)) else "Ironman")


func _save(slot: String, label: String) -> String:
	var data: Dictionary = capture(label)
	if data.is_empty():
		return "Nothing to save yet."
	var error: String = _write_json(root.path_join(pilot_id).path_join(slot + ".json"), data)
	if error == "":
		_write_pilot()
		saved.emit(slot)
	return error


## SV1: the live game as a pilot file.
func capture(label: String) -> Dictionary:
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	if player == null or player.health.is_destroyed:
		return {}  # SV3: no saving out of a destroyed ship (the pod's fate comes first)
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if scene != null:
		scene.remember_wrecks()  # PS6: this system's wrecks live as ships until written down
		scene.entity_presence.snapshot()  # PS4, EC6: entities here as they are now (cargo included)
	var record: Dictionary = ShipRecord.make(player.def.id, player.health.armor / maxf(player.health.max_armor, 0.001),
		player.health.shield / maxf(player.health.max_shield, 0.001))
	record["cargo"] = player.cargo.duplicate(true)  # EC3
	var where: Dictionary = PilotSave.location(GameState.travel.current_system, landed_at,
		player.global_position, player.get_velocity(), player.global_rotation)
	return PilotSave.build(label, Time.get_datetime_string_from_system(false, true), pilot, GameState.to_dict(), record, where)


## SV1, SV4: reads, upgrades and checks a save. {"ok", "data", "error", "warnings"}.
func read(id: String, slot: String) -> Dictionary:
	var raw: Dictionary = _read_json(root.path_join(id).path_join(slot + ".json"))
	if raw.is_empty():
		return {"ok": false, "data": {}, "error": "That save can't be read.", "warnings": []}
	var upgraded: Dictionary = SaveMigrations.upgrade(raw)
	if not upgraded["ok"]:
		return {"ok": false, "data": {}, "error": upgraded["error"], "warnings": []}
	var ships: Dictionary = {}
	for ship_id: String in DataRegistry.ids("ships"):
		ships[ship_id] = true
	var systems: Dictionary = {}
	for system_id: String in DataRegistry.ids("systems"):
		systems[system_id] = true
	var checked: Dictionary = PilotSave.check(upgraded["data"], ships, systems, str(DataRegistry.settings["player"]["uninsured_ship"]))
	return {"ok": checked["ok"], "data": checked["data"], "error": "\n".join(checked["errors"]), "warnings": checked["warnings"]}


## SV2: loads a save and (re)starts the system scene in it. Returns "" or why not.
func load_save(id: String, slot: String) -> String:
	var block: Dictionary = _read_json(root.path_join(id).path_join("pilot.json"))
	if block.is_empty():
		return "That pilot can't be read."
	if not PilotSave.can_load(block, slot):
		return "%s can't be loaded." % ("A dead pilot's save" if bool(block.get("dead", false)) else "That save")
	var result: Dictionary = read(id, slot)
	if not result["ok"]:
		return result["error"]
	var data: Dictionary = result["data"]
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if scene != null:
		scene.entity_presence.on_leave()  # the old visit writes back now, not into the loaded state
	pilot_id = id
	pilot = block.duplicate()
	for key: String in ["escape_pod", "insured"]:  # SV1: as they were in this save
		if data["pilot"].has(key):
			pilot[key] = data["pilot"][key]
	GameState.from_dict(data["game"])
	pending = data["player"]
	landed_at = ""
	for warning: String in result["warnings"]:
		push_warning(warning)
	get_tree().paused = false
	get_tree().change_scene_to_file(SYSTEM_SCENE)
	return ""


## SV2: the newest loadable save of any pilot ({id, slot} or {}).
func latest() -> Dictionary:
	for entry: Dictionary in list_pilots():
		for meta: Dictionary in entry["slots"]:
			if PilotSave.can_load(entry["pilot"], meta["id"]):
				return {"id": entry["id"], "slot": meta["id"]}
	return {}


# --- Files -------------------------------------------------------------------

func _write_json(path: String, data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# Write a temporary file, then swap it in, so a crash mid-write never
	# leaves a half-written save (an ironman has only one).
	var temp: String = path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "Couldn't write %s (%s)." % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var error: Error = DirAccess.rename_absolute(temp, path)
	return "" if error == OK else "Couldn't write %s (%s)." % [path, error_string(error)]


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## SV3: back to the main menu; an ironman's slot is written first
## (`write_ironman`), so quitting never loses or rewinds its story.
func quit_to_menu(write_ironman: bool = true) -> void:
	if write_ironman:
		_write_ironman()
	pilot_id = ""
	pilot = {}
	pending = {}
	landed_at = ""
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)

