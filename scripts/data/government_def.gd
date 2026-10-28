class_name GovernmentDef
extends Def
## A faction (data/governments). Used from milestone 4.

const PENALTY_KINDS: Array[String] = ["shoot", "disable", "board", "kill"]

var name: String
var colour: Color
var allies: Array[String] = []
var enemies: Array[String] = []
var crime_threshold: float
## "shoot" / "disable" / "board" / "kill" -> record lost.
var penalties: Dictionary = {}
var max_odds: float
var flee_shield_pct: float
## A8: grievance (% of a ship's total shield + armour damaged by the player)
## its ships tolerate before turning hostile, and how fast it drains (%/s).
var tolerance_pct: float
var forgiveness_pct_per_s: float


static func parse(r: DefReader) -> GovernmentDef:
	var d := GovernmentDef.new()
	d.name = r.string("name", "", true)
	d.colour = r.colour("colour", Color.WHITE)
	d.allies = r.ref_array("allies", "governments")
	d.enemies = r.ref_array("enemies", "governments")
	d.crime_threshold = r.number("crime_threshold", -50.0)
	var pen: DefReader = r.object("penalties")
	for kind: String in PENALTY_KINDS:
		d.penalties[kind] = pen.number(kind, 0.0, false, 0.0)
	d.max_odds = r.number("max_odds", 1.0, false, 0.0)
	d.flee_shield_pct = r.number("flee_shield_pct", 25.0, false, 0.0)
	d.tolerance_pct = r.number("tolerance_pct", 20.0, false, 0.0)
	d.forgiveness_pct_per_s = r.number("forgiveness_pct_per_s", 4.0, false, 0.0)
	return d


func validate(_defs: Dictionary, errors: Array[String]) -> void:
	for other: String in allies:
		if other in enemies:
			errors.append("%s: field 'allies': '%s' is also listed in 'enemies'" % [file, other])
	if id in allies or id in enemies:
		errors.append("%s: a government cannot list itself as an ally or enemy" % file)
