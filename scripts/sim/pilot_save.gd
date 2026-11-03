class_name PilotSave
extends RefCounted
## SV1–SV3: the pilot file and the rules for pilots and save slots. Pure: the
## Pilots autoload does the disk work and gathers the live game state.
##
## A save is:
##   version   SaveMigrations.VERSION
##   meta      {slot, saved_at, system, day, credits, ship}: for menus only
##   pilot     {name, ironman, dead, escape_pod, insured, created_day}
##   game      GameState.to_dict() (credits, records, date, route, flags,
##             system memory, persistent entities, news)
##   player    {ship: ShipRecord, location: {system, landed, position,
##             velocity, rotation}}; `landed` is a planet id or ""
##   stats, ratings, missions   reserved (milestones 7–8), empty for now

## Normal pilots' autosave slot; ironman pilots' only slot.
const AUTOSAVE: String = "autosave"
const IRONMAN: String = "ironman"


static func empty() -> Dictionary:
	return {"version": SaveMigrations.VERSION, "meta": {}, "pilot": new_pilot("", false, {}), "game": {},
		"player": {"ship": ShipRecord.make(""), "location": location("", "", Vector2.ZERO, Vector2.ZERO, 0.0)},
		"stats": {}, "ratings": {}, "missions": {}}


## `player_settings`: game.json "player" (escape pod and insurance start there).
static func new_pilot(pilot_name: String, ironman: bool, player_settings: Dictionary, day: int = 0) -> Dictionary:
	return {"name": pilot_name, "ironman": ironman, "dead": false,
		"escape_pod": bool(player_settings.get("escape_pod", true)), "insured": bool(player_settings.get("insured", true)),
		"created_day": day}


static func location(system_id: String, landed: String, position: Vector2, velocity: Vector2, rotation: float) -> Dictionary:
	return {"system": system_id, "landed": landed, "position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y], "rotation": rotation}


static func build(slot: String, saved_at: String, pilot: Dictionary, game: Dictionary, ship: Dictionary, where: Dictionary) -> Dictionary:
	var save: Dictionary = empty()
	save["pilot"] = pilot.duplicate(true)
	save["game"] = game.duplicate(true)
	save["player"] = {"ship": ship.duplicate(true), "location": where.duplicate(true)}
	save["meta"] = {"slot": slot, "saved_at": saved_at, "system": where.get("system", ""), "day": int(game.get("day", 0)),
		"credits": int(game.get("credits", 0)), "ship": ShipRecord.design_of(ship)}
	return save


## SV1: checks a (migrated) save against the data that's loaded now.
## `ships`, `systems`: sets of ids. Missing ship designs become `fallback`
## (the uninsured hull) with a warning; wrecks of missing designs are dropped;
## a missing current system is an error.
## Returns {"ok": bool, "data": Dictionary, "errors": [String], "warnings": [String]}.
static func check(save: Dictionary, ships: Dictionary, systems: Dictionary, fallback: String) -> Dictionary:
	var data: Dictionary = save.duplicate(true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var where: String = str(data["player"]["location"].get("system", ""))
	if not systems.has(where):
		errors.append("The system this pilot is in ('%s') no longer exists." % where)
	var ship: Dictionary = data["player"]["ship"]
	if not ships.has(ShipRecord.design_of(ship)):
		warnings.append("Your ship design '%s' no longer exists; you have a %s instead." % [ShipRecord.design_of(ship), fallback])
		data["player"]["ship"] = ShipRecord.make(fallback)
	var states: Dictionary = data["game"].get("entities", {}).get("states", {})
	for id: String in states:
		for record: Dictionary in states[id].get("ships", []):
			if not ships.has(ShipRecord.design_of(record)):
				warnings.append("%s's '%s' no longer exists; replaced by a %s." % [id, ShipRecord.design_of(record), fallback])
				record["design"] = fallback
	var wrecks: Dictionary = data["game"].get("memory", {}).get("wrecks", {})
	for system_id: String in wrecks:
		var kept: Array = []
		for wreck: Dictionary in wrecks[system_id]:
			if ships.has(ShipRecord.design_of(wreck)):
				kept.append(wreck)
			else:
				warnings.append("A wreck of '%s' in %s was removed (design no longer exists)." % [ShipRecord.design_of(wreck), system_id])
		wrecks[system_id] = kept
	return {"ok": errors.is_empty(), "data": data, "errors": errors, "warnings": warnings}


## SV2: a new pilot needs a free place (`limit` pilots at once).
static func can_create_pilot(pilot_count: int, limit: int) -> bool:
	return pilot_count < limit


## SV2, SV3: may this pilot write manual slot `slot` now? `manual_slots`: its
## existing manual slot ids. Ironman and dead pilots have no manual saves; a
## full set can only be overwritten.
static func can_save_manual(pilot: Dictionary, slot: String, manual_slots: Array, limit: int) -> bool:
	if bool(pilot.get("ironman", false)) or bool(pilot.get("dead", false)):
		return false
	if slot == "" or slot == AUTOSAVE or slot == IRONMAN:
		return false
	return manual_slots.has(slot) or manual_slots.size() < limit


## SV3: the slot an autosave writes.
static func autosave_slot(pilot: Dictionary) -> String:
	return IRONMAN if bool(pilot.get("ironman", false)) else AUTOSAVE


## SV3: can this pilot's save be loaded? Dead pilots are memorials. An
## ironman can only continue from its one slot.
static func can_load(pilot: Dictionary, slot: String) -> bool:
	if bool(pilot.get("dead", false)):
		return false
	return slot == IRONMAN if bool(pilot.get("ironman", false)) else slot != IRONMAN


## A file-safe id from a name: lowercase letters, digits and underscores;
## made unique against `taken`.
static func slug(text: String, taken: Array = []) -> String:
	var out: String = ""
	for c: String in text.to_lower().strip_edges():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif not out.ends_with("_") and out != "":
			out += "_"
	out = out.trim_suffix("_")
	if out == "":
		out = "pilot"
	var unique: String = out
	var n: int = 2
	while taken.has(unique):
		unique = "%s_%d" % [out, n]
		n += 1
	return unique
