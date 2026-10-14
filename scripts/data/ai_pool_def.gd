class_name AiPoolDef
extends Def
## A traffic type, Nova's "dude" (data/ai_pools). Used from milestone 4.

const BEHAVIOURS: Array[String] = ["trader", "warship", "pirate"]

var government: String
var behaviour: String
## [{"ship": String, "weight": float}]
var ships: Array[Dictionary] = []


static func parse(r: DefReader) -> AiPoolDef:
	var d := AiPoolDef.new()
	d.government = r.ref("government", "governments", "", true)
	d.behaviour = r.choice("behaviour", BEHAVIOURS, "trader", true)
	var list: Array[DefReader] = r.objects("ships", true)
	if r.has("ships") and list.is_empty():
		r.error("ships", "needs at least one ship")
	for s: DefReader in list:
		d.ships.append({"ship": s.ref("ship", "ships", "", true), "weight": s.number("weight", 1.0, false, 0.0)})
	return d
