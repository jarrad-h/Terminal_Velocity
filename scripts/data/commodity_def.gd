class_name CommodityDef
extends Def
## EC1, EC4: a trade good (data/commodities). Ports price it by tier (EC1).

var name: String
## Credits per unit at a medium-tier market, before saturation and events.
var base_price: float
## Tons per unit (cargo space, EC3).
var mass: float
## EC4: governments that outlaw it (no penalty until scanning, Phase 3).
var illegal_to: Array[String] = []


static func parse(r: DefReader) -> CommodityDef:
	var d := CommodityDef.new()
	d.name = r.string("name", "", true)
	d.base_price = r.number("base_price", 0.0, true, 1.0)
	d.mass = r.number("mass", 1.0, false, 0.01)
	d.illegal_to = r.ref_array("illegal_to", "governments")
	return d
