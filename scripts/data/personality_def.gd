class_name PersonalityDef
extends Def
## A7: an individual AI temperament (data/personalities). Shades behaviour
## within the group's rules (government + AI pool); never changes who is a
## friend or enemy.

const RESPONSES: Array[String] = ["role", "fight", "flee"]
const INITIATIVE: Array[String] = ["role", "never", "on_sight"]

var name: String = "Steady"
## Multiplies the government's max_odds (A5).
var odds_factor: float = 1.0
## Percentage points added to the government's flee_shield_pct (A4).
var flee_shield_offset: float = 0.0
## "role" (traders flee, others fight), "fight" or "flee".
var when_attacked: String = "role"
## "role" (warships and pirates on sight, traders never), "never" or "on_sight".
var starts_fights: String = "role"


static func parse(r: DefReader) -> PersonalityDef:
	var d := PersonalityDef.new()
	d.name = r.string("name", "", true)
	d.odds_factor = r.number("odds_factor", 1.0, false, 0.0)
	d.flee_shield_offset = r.number("flee_shield_offset", 0.0)
	d.when_attacked = r.choice("when_attacked", RESPONSES, "role")
	d.starts_fights = r.choice("starts_fights", INITIATIVE, "role")
	return d


## Used when a pool lists no personalities: changes nothing.
static func neutral() -> PersonalityDef:
	return PersonalityDef.new()
