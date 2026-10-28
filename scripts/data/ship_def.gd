class_name ShipDef
extends Def
## A hull class (data/ships). Defaults are documented in data/README.md.

const HARDPOINT_KINDS: Array[String] = ["gun", "turret", "guided", "beam"]

var name: String
var sprite: String
var mass: float
var accel: float
var top_speed: float
var turn_rate: float
var shield: float
var shield_regen: float
## C6: seconds without damage before shields recharge.
var shield_recharge_delay: float
var armor: float
## C7: disabled at or below this % of max armour.
var disable_armor_pct: float
var strength: float
var crew: int
var hit_radius: float
## C9: credits aboard [min, max] before the AI pool's wealth factor.
var board_credits: Vector2
## Kind ("gun", "turret"…) -> Array of Vector2 exit points, relative to the ship centre, ship facing up.
var hardpoints: Dictionary = {}
## [{"weapon": String, "count": int}]
var default_weapons: Array[Dictionary] = []


static func parse(r: DefReader) -> ShipDef:
	var d := ShipDef.new()
	d.name = r.string("name", "", true)
	d.sprite = r.string("sprite")
	d.mass = r.number("mass", 50.0, false, 0.0)
	d.accel = r.number("accel", 0.0, true, 0.0)
	d.top_speed = r.number("top_speed", 0.0, true, 0.0)
	d.turn_rate = r.number("turn_rate", 0.0, true, 0.0)
	d.shield = r.number("shield", 0.0, false, 0.0)
	d.shield_regen = r.number("shield_regen", 0.0, false, 0.0)
	d.shield_recharge_delay = r.number("shield_recharge_delay", 3.0, false, 0.0)
	d.armor = r.number("armor", 100.0, false, 0.0)
	d.disable_armor_pct = r.number("disable_armor_pct", 33.0, false, 0.0)
	d.strength = r.number("strength", 1.0, false, 0.0)
	d.crew = r.integer("crew", 1, false, 0)
	d.hit_radius = r.number("hit_radius", 16.0, false, 1.0)
	d.board_credits = r.range2("board_credits", Vector2.ZERO, 0.0)
	var points: DefReader = r.object("hardpoints")
	for kind: String in HARDPOINT_KINDS:
		var list: Array[Vector2] = []
		var raw: Array = points.array(kind)
		for i: int in raw.size():
			var p: Variant = raw[i]
			if p is Array and p.size() == 2 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int):
				list.append(Vector2(p[0], p[1]))
			else:
				points.error("%s[%d]" % [kind, i], "expected [x, y]")
		d.hardpoints[kind] = list
	for w: DefReader in r.objects("default_weapons"):
		d.default_weapons.append({"weapon": w.ref("weapon", "weapons", "", true), "count": w.integer("count", 1, false, 1)})
	return d


## C1: each equipped weapon needs at least one exit point of its kind.
func validate(defs: Dictionary, errors: Array[String]) -> void:
	for i: int in default_weapons.size():
		var weapon: WeaponDef = defs["weapons"].get(default_weapons[i]["weapon"])
		if weapon != null and hardpoints[weapon.kind].is_empty():
			errors.append("%s: field 'default_weapons[%d]': '%s' is a %s weapon but 'hardpoints' has no %s exit points" \
				% [file, i, weapon.id, weapon.kind, weapon.kind])
