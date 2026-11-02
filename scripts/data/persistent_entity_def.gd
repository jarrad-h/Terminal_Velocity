class_name PersistentEntityDef
extends Def
## PS2: a named character or fleet tracked across the galaxy (data/entities).
## Its ships fly with the behaviour of an AI pool (role, sensors, wealth) when
## they materialise (PS4); off-screen it is a summary moved by the day clock.

const ORDER_TYPES: Array[String] = ["hold", "patrol", "travel", "follow"]

var name: String
var government: String
## AI pool its ships fly as (behaviour, sensor range, wealth factor…).
var pool: String
## Personality ID ("" = neutral).
var personality: String
## [{"ship": String, "count": int}]
var ships: Array[Dictionary] = []
var start_system: String
## "hold" (stay at start), "patrol" (visit `route` in order, looping),
## "travel" (go to `destination`, then hold) or "follow" (the player).
var order_type: String
var route: Array[String] = []
var destination: String
## Days spent at each stop [min, max].
var stay_days: Vector2i
## PS4: seconds from the player's entry to this entity's arrival on the same
## day [min, max]; negative = already there. Empty = game.json default.
var arrival_offset: Vector2 = Vector2.ZERO
var has_arrival_offset: bool = false
## PS4: how its ships fly together: "none", "wedge" or "line" (Formation).
var formation: String
## PS2: days it follows the player after the player damages it (0 = never).
var grudge_days: int
## Exists while this condition holds ("" always, "flag", "!flag"; the
## milestone 7 grammar will read the same field).
var exists_if: String


static func parse(r: DefReader) -> PersistentEntityDef:
	var d := PersistentEntityDef.new()
	d.name = r.string("name", "", true)
	d.government = r.ref("government", "governments", "", true)
	d.pool = r.ref("pool", "ai_pools", "", true)
	d.personality = r.ref("personality", "personalities")
	for s: DefReader in r.objects("ships", true):
		d.ships.append({"ship": s.ref("ship", "ships", "", true), "count": s.integer("count", 1, false, 1)})
	if d.ships.is_empty():
		r.error("ships", "needs at least one ship")
	d.start_system = r.ref("start_system", "systems", "", true)
	var orders: DefReader = r.object("orders")
	d.order_type = orders.choice("type", ORDER_TYPES, "hold")
	d.route = orders.ref_array("route", "systems")
	d.destination = orders.ref("destination", "systems")
	var stay: Vector2 = orders.range2("stay_days", Vector2(1.0, 2.0), 0.0)
	d.stay_days = Vector2i(roundi(stay.x), roundi(stay.y))
	if d.order_type == "patrol" and d.route.size() < 2:
		orders.error("route", "a patrol needs at least two systems")
	if d.order_type == "travel" and d.destination == "":
		orders.error("destination", "is required for travel orders")
	if r.has("arrival_offset"):
		d.arrival_offset = r.range2("arrival_offset")
		d.has_arrival_offset = true
	d.grudge_days = r.integer("grudge_days", 0, false, 0)
	d.formation = r.choice("formation", Formation.TYPES, "none")
	d.exists_if = r.string("exists_if")
	if not GateRules.is_valid_condition(d.exists_if):
		r.error("exists_if", "expected \"\", \"flag_name\" or \"!flag_name\" (lowercase snake_case)")
	return d


## Every system it names must be on the galaxy map.
func validate(defs: Dictionary, errors: Array[String]) -> void:
	for galaxy: GalaxyDef in defs.get("galaxy", {}).values():
		for system_id: String in [start_system, destination] + route:
			if system_id != "" and not galaxy.has_system(system_id):
				errors.append("%s: '%s' is not on the %s map" % [file, system_id, galaxy.name])
