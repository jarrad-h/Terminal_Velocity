class_name SystemObjectDef
extends Resource
## A star, planet, station or gas giant in a system (S1). Drawn from milestone 5.

const TYPES: Array[String] = ["star", "planet", "station"]

var id: String
var type: String
var name: String
var position: Vector2
var radius: float
var colour: Color
var sprite: String
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


static func parse(r: DefReader) -> SystemObjectDef:
	var o := SystemObjectDef.new()
	o.id = r.string("id", "", true)
	o.type = r.choice("type", TYPES, "planet", true)
	o.name = r.string("name", "", true)
	o.position = r.vec2("position", Vector2.ZERO, true)
	o.radius = r.number("radius", 100.0, false, 1.0)
	o.colour = r.colour("colour", Color(0.5, 0.6, 0.8))
	o.sprite = r.string("sprite")
	o.description = r.string("description")
	o.landable = r.boolean("landable", false)
	o.government = r.ref("government", "governments")
	o.min_record = r.number("min_record", -1000.0)
	o.sells_fuel = r.boolean("sells_fuel", true)
	o.refuel_price = r.number("refuel_price", 2.0, false, 0.0)
	o.landing_days = r.integer("landing_days", 1, false, 0)
	o.takeoff_days = r.integer("takeoff_days", 0, false, 0)
	return o
