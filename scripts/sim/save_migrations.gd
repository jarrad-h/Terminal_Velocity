class_name SaveMigrations
extends RefCounted
## SV4: pilot files carry a version. Older files are upgraded one step at a
## time; files from a newer game, or older than the oldest supported, are
## refused with a message. Pure: dictionaries in, dictionaries out.

const VERSION: int = 1
## Oldest version that can still be upgraded.
const OLDEST: int = 0


## Returns {"ok": bool, "data": Dictionary (upgraded), "error": String}.
static func upgrade(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version > VERSION:
		return {"ok": false, "data": data, "error": "This save is from a newer version of the game (save format %d; this game reads up to %d)." % [version, VERSION]}
	if version < OLDEST:
		return {"ok": false, "data": data, "error": "This save is too old to load (save format %d; the oldest this game reads is %d)." % [version, OLDEST]}
	var out: Dictionary = data.duplicate(true)
	while int(out.get("version", 0)) < VERSION:
		match int(out.get("version", 0)):
			0:
				out = _v0_to_v1(out)
	return {"ok": true, "data": out, "error": ""}


## Version 0 (milestone 3, before pilot files): a bare game state with ships
## named by "ship". Version 1 wraps it in a pilot file and uses ShipRecord.
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	var game: Dictionary = data.get("game", data).duplicate(true)
	game.erase("version")
	var entities: Dictionary = game.get("entities", {})
	var states: Dictionary = entities.get("states", {})
	for id: String in states:
		var ships: Array = []
		for ship: Dictionary in states[id].get("ships", []):
			ships.append(ShipRecord.normalised(ship))
		states[id]["ships"] = ships
	var memory: Dictionary = game.get("memory", {})
	var wrecks: Dictionary = memory.get("wrecks", {})
	for system_id: String in wrecks:
		var list: Array = []
		for wreck: Dictionary in wrecks[system_id]:
			list.append(ShipRecord.normalised(wreck))
		wrecks[system_id] = list
	var out: Dictionary = PilotSave.empty()
	out["game"] = game
	for key: String in ["pilot", "player"]:
		if data.has(key):
			out[key] = data[key]
	if str(out["player"]["location"].get("system", "")) == "":
		out["player"]["location"]["system"] = str(game.get("travel", {}).get("current_system", ""))
	return out
