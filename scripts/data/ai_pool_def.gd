class_name AiPoolDef
extends Def
## A traffic type, Nova's "dude" (data/ai_pools). Used from milestone 4.

const BEHAVIOURS: Array[String] = ["trader", "warship", "pirate"]

var government: String
var behaviour: String
## [{"ship": String, "weight": float}]
var ships: Array[Dictionary] = []
## A7: [{"personality": String, "weight": float}]; empty = neutral temperament.
var personalities: Array[Dictionary] = []
## How far its ships notice others, px.
var sensor_range: float
## Warships and pirates leave after this many seconds with nothing to fight.
var stay_time: Vector2
## Traders: seconds docked at each planet.
var dwell_time: Vector2
## Traders: planets visited before leaving (whole numbers).
var stops: Vector2i
## A6: new ships may take off from landable planets instead of arriving at the edge.
var spawn_from_planets: bool
## Fire only when the aim is within this many degrees.
var fire_angle: float
## C9: multiplies the hull's board_credits (traders rich, patrols poor).
var wealth_factor: float


static func parse(r: DefReader) -> AiPoolDef:
	var d := AiPoolDef.new()
	d.government = r.ref("government", "governments", "", true)
	d.behaviour = r.choice("behaviour", BEHAVIOURS, "trader", true)
	var list: Array[DefReader] = r.objects("ships", true)
	if r.has("ships") and list.is_empty():
		r.error("ships", "needs at least one ship")
	for s: DefReader in list:
		d.ships.append({"ship": s.ref("ship", "ships", "", true), "weight": s.number("weight", 1.0, false, 0.0)})
	for p: DefReader in r.objects("personalities"):
		d.personalities.append({"personality": p.ref("personality", "personalities", "", true), "weight": p.number("weight", 1.0, false, 0.0)})
	if not d.ships.is_empty() and _total_weight(d.ships) <= 0.0:
		r.error("ships", "weights add up to 0; at least one ship needs a weight above 0")
	if not d.personalities.is_empty() and _total_weight(d.personalities) <= 0.0:
		r.error("personalities", "weights add up to 0; at least one personality needs a weight above 0")
	d.sensor_range = r.number("sensor_range", 1500.0, false, 0.0)
	d.stay_time = r.range2("stay_time", Vector2(60.0, 120.0), 0.0)
	d.dwell_time = r.range2("dwell_time", Vector2(6.0, 12.0), 0.0)
	var stops: Vector2 = r.range2("stops", Vector2(1.0, 3.0), 0.0)
	d.stops = Vector2i(roundi(stops.x), roundi(stops.y))
	d.spawn_from_planets = r.boolean("spawn_from_planets", d.behaviour == "trader")
	d.fire_angle = r.number("fire_angle", 8.0, false, 0.0)
	d.wealth_factor = r.number("wealth_factor", 1.0, false, 0.0)
	return d


static func _total_weight(list: Array[Dictionary]) -> float:
	var total: float = 0.0
	for item: Dictionary in list:
		total += item["weight"]
	return total
