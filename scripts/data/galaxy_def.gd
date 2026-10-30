class_name GalaxyDef
extends Def
## The cluster of systems and the hyperlanes between them (data/galaxy, TR1, TR7).
## Map positions are in map units; a jump's days are lane length ÷ the ship's
## jump speed (TM2).

## TR7: how a system starts on the map. Game state can change it later
## (visiting explores it, a reveal makes a hidden system unexplored).
const MAP_STATES: Array[String] = ["explored", "unexplored", "hidden"]

var name: String
var start_system: String
## System IDs in file order.
var system_ids: Array[String] = []
var positions: Dictionary[String, Vector2] = {}
var start_states: Dictionary[String, String] = {}
## [{"from": String, "to": String}], each pair once in either direction.
var lanes: Array[Dictionary] = []


static func parse(r: DefReader) -> GalaxyDef:
	var d := GalaxyDef.new()
	d.name = r.string("name", "", true)
	d.start_system = r.ref("start_system", "systems", "", true)
	for s: DefReader in r.objects("systems", true):
		var id: String = s.ref("system", "systems", "", true)
		if d.positions.has(id):
			s.error("system", "'%s' is listed twice" % id)
			continue
		d.system_ids.append(id)
		d.positions[id] = s.vec2("position", Vector2.ZERO, true)
		d.start_states[id] = s.choice("map_state", MAP_STATES, "unexplored")
	for l: DefReader in r.objects("hyperlanes"):
		d.lanes.append({"from": l.string("from", "", true), "to": l.string("to", "", true)})
	return d


func has_system(system_id: String) -> bool:
	return positions.has(system_id)


## TR1: every lane joins two different listed systems, at most once; the
## start system is listed and not hidden.
func validate(_defs: Dictionary, errors: Array[String]) -> void:
	if start_system != "" and not has_system(start_system):
		errors.append("%s: field 'start_system': '%s' is not in this galaxy's systems" % [file, start_system])
	elif start_states.get(start_system, "") == "hidden":
		errors.append("%s: field 'start_system': '%s' starts hidden; the player must be able to see where they are" % [file, start_system])
	var seen: Dictionary = {}
	for i: int in lanes.size():
		var field: String = "%s: field 'hyperlanes[%d]'" % [file, i]
		var a: String = lanes[i]["from"]
		var b: String = lanes[i]["to"]
		for end: String in [a, b]:
			if end != "" and not has_system(end):
				errors.append("%s: '%s' is not in this galaxy's systems" % [field, end])
		if a == b:
			errors.append("%s: a hyperlane must join two different systems" % field)
			continue
		var key: String = "%s|%s" % ([a, b] if a < b else [b, a])
		if seen.has(key):
			errors.append("%s: %s to %s is already listed" % [field, a, b])
		seen[key] = true
