class_name WeaponDef
extends Def
## A gun, turret, missile or beam (data/weapons). Used from milestone 3.
## For beams, damage is per second while firing.

const KINDS: Array[String] = ["gun", "turret", "guided", "beam"]

var name: String
var kind: String
var damage_shield: float
var damage_armor: float
## Max distance in px. 0 means the shot lives for `lifetime` instead.
var max_range: float
var lifetime: float
var speed: float
var reload: float
var turn_rate: float
var arc: float
var colour: Color
## C12: full damage up to this % of range, then linear down to falloff_min_pct.
var falloff_start_pct: float
var falloff_min_pct: float
## Guns and turrets: shots add the firing ship's velocity.
var inherit_velocity: bool
var sprite: String
var sound: String


static func parse(r: DefReader) -> WeaponDef:
	var d := WeaponDef.new()
	d.name = r.string("name", "", true)
	d.kind = r.choice("kind", KINDS, "gun", true)
	d.damage_shield = r.number("damage_shield", 0.0, false, 0.0)
	d.damage_armor = r.number("damage_armor", 0.0, false, 0.0)
	d.max_range = r.number("range", 0.0, false, 0.0)
	d.lifetime = r.number("lifetime", 1.0, false, 0.0)
	d.speed = r.number("speed", 600.0, false, 0.0)
	d.reload = r.number("reload", 0.5, false, 0.0)
	d.turn_rate = r.number("turn_rate", 0.0, false, 0.0)
	d.arc = r.number("arc", 360.0, false, 0.0)
	d.colour = r.colour("colour", Color.WHITE)
	d.inherit_velocity = r.boolean("inherit_velocity", true)
	d.falloff_start_pct = r.number("falloff_start_pct", 100.0, false, 0.0)
	d.falloff_min_pct = r.number("falloff_min_pct", 100.0, false, 0.0)
	for key: String in ["falloff_start_pct", "falloff_min_pct"]:
		if r.has(key) and float(r.data[key]) > 100.0:
			r.error(key, "must be at most 100")
	d.sprite = r.string("sprite")
	d.sound = r.string("sound")
	return d


## Seconds a projectile or missile lives: range ÷ speed if a range is set.
func shot_lifetime() -> float:
	if max_range > 0.0 and speed > 0.0:
		return max_range / speed
	return lifetime


## Beam length: the range, or speed × lifetime when no range is set.
func beam_length() -> float:
	return max_range if max_range > 0.0 else speed * lifetime


## Distance at which damage stops falling (beam length, or how far a shot can travel).
func reach() -> float:
	return beam_length() if kind == "beam" else speed * shot_lifetime()


## C12: damage multiplier after `distance`.
func falloff_at(distance: float) -> float:
	return DamageModel.falloff(distance, reach(), falloff_start_pct, falloff_min_pct)
