class_name SystemObjectDef
extends Resource
## A star, planet, station, gas giant or gate in a system (S1, TR5).

const TYPES: Array[String] = ["star", "planet", "station", "gate"]

var id: String
var type: String
var name: String
var position: Vector2
var radius: float
var colour: Color
## V9: art set drawn for it (assets/sprites/stellars, StellarArt); "" draws
## the flat placeholder.
var art: String
var description: String
var landable: bool
var government: String
var min_record: float
## TR8: landed ships can buy fuel here, at this many credits per unit.
var sells_fuel: bool
var refuel_price: float
## TM2: days that pass on landing and on taking off.
var landing_days: int
var takeoff_days: int
## TR6 (gates): credits charged to travel from this gate, and when it is open
## ("" always, "flag" while set, "!flag" while not; GateRules.is_open).
var fee: int
var open_condition: String


static func parse(r: DefReader) -> SystemObjectDef:
	var o := SystemObjectDef.new()
	o.id = r.string("id", "", true)
	o.type = r.choice("type", TYPES, "planet", true)
	o.name = r.string("name", "", true)
	o.position = r.vec2("position", Vector2.ZERO, true)
	o.radius = r.number("radius", 100.0, false, 1.0)
	o.colour = r.colour("colour", Color(0.5, 0.6, 0.8))
	o.art = r.string("art")
	if o.art != "":
		var base: String = StellarArt.base_path(o.art)
		var folder: String = {"star": "stars", "planet": "planets", "station": "stations", "gate": "gates"}[o.type]
		if base == "":
			r.error("art", "no art set '%s' in %s" % [o.art, StellarArt.ROOT])
		elif base.get_base_dir().get_file() != folder:
			r.error("art", "'%s' is %s art, not for a %s" % [o.art, base.get_base_dir().get_file(), o.type])
	o.description = r.string("description")
	o.landable = r.boolean("landable", false)
	o.government = r.ref("government", "governments")
	o.min_record = r.number("min_record", -1000.0)
	o.sells_fuel = r.boolean("sells_fuel", true)
	o.refuel_price = r.number("refuel_price", 2.0, false, 0.0)
	o.landing_days = r.integer("landing_days", 1, false, 0)
	o.takeoff_days = r.integer("takeoff_days", 0, false, 0)
	o.fee = r.integer("fee", 0, false, 0)
	o.open_condition = r.string("open_condition")
	if not GateRules.is_valid_condition(o.open_condition):
		r.error("open_condition", "expected \"\", \"flag_name\" or \"!flag_name\" (lowercase snake_case)")
	for key: String in ["fee", "open_condition"]:
		if r.has(key) and o.type != "gate":
			r.error(key, "only gates have a %s" % key)
	return o
