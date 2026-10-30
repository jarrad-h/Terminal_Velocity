class_name TravelState
extends RefCounted
## The player's travel state (TR1, TR7, TR8): where they are, fuel, the
## plotted route and how the map has changed from the galaxy's starting
## states. Plain values only, with to_dict / from_dict, so the saves milestone
## (SV1) can store it unchanged.

var current_system: String = ""
var fuel: float = 0.0
## TR7: the plotted route, next jump first; route[0] is the selected destination.
var route: Array[String] = []
## TR7: system id -> map state ("explored", "unexplored", "hidden") where it
## differs from the galaxy's starting state.
var map_changes: Dictionary = {}


## TR7: the system's current map state.
func map_state(galaxy: GalaxyDef, system_id: String) -> String:
	return map_changes.get(system_id, galaxy.start_states.get(system_id, "hidden"))


func mark_explored(system_id: String) -> void:
	map_changes[system_id] = "explored"


## TR7: a hidden system becomes unexplored (a bought map, intel, a found gate,
## a mission; debug for now). Returns false if it wasn't hidden.
func reveal(galaxy: GalaxyDef, system_id: String) -> bool:
	if not galaxy.has_system(system_id) or map_state(galaxy, system_id) != "hidden":
		return false
	map_changes[system_id] = "unexplored"
	return true


## Set (id -> true) of systems currently hidden, for Hyperlanes queries.
func hidden_set(galaxy: GalaxyDef) -> Dictionary:
	var hidden: Dictionary = {}
	for id: String in galaxy.system_ids:
		if map_state(galaxy, id) == "hidden":
			hidden[id] = true
	return hidden


## The next jump's destination, or "".
func destination() -> String:
	return route[0] if not route.is_empty() else ""


func to_dict() -> Dictionary:
	return {"current_system": current_system, "fuel": fuel, "route": route.duplicate(), "map_changes": map_changes.duplicate()}


static func from_dict(data: Dictionary) -> TravelState:
	var state := TravelState.new()
	state.current_system = str(data.get("current_system", ""))
	state.fuel = float(data.get("fuel", 0.0))
	for id: Variant in data.get("route", []):
		state.route.append(str(id))
	var changes: Variant = data.get("map_changes", {})
	if changes is Dictionary:
		state.map_changes = changes.duplicate()
	return state
