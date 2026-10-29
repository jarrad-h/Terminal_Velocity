class_name WeaponDef
extends Def
## A laser, flak, beam or missile (data/weapons). For beams, damage is per
## second while firing. V3: a weapon has a size and the mount types it comes
## in; its numbers are the same on every mount, only the aiming differs.

const KINDS: Array[String] = ["projectile", "beam", "guided"]

var name: String
var kind: String
var size: String
var mounts: Array[String] = []
var damage_shield: float
var damage_armor: float
## Max distance in px. 0 means the shot lives for `lifetime` instead.
var max_range: float
var lifetime: float
var speed: float
var reload: float
var turn_rate: float
var colour: Color
## C12: full damage up to this % of range, then linear down to falloff_min_pct.
var falloff_start_pct: float
var falloff_min_pct: float
## Projectiles: shots add the firing ship's velocity.
var inherit_velocity: bool
var sprite: String
var sound: String


static func parse(r: DefReader) -> WeaponDef:
	var d := WeaponDef.new()
	d.name = r.string("name", "", true)
	d.kind = r.choice("kind", KINDS, "projectile", true)
	d.size = r.choice("size", MountFit.SIZES, "small")
	if not r.has("mounts"):
		r.error("mounts", "is required")
	var mounts: Array[String] = r.string_array("mounts")
	if r.has("mounts") and mounts.is_empty():
		r.error("mounts", "needs at least one mount type")
	for i: int in mounts.size():
		if mounts[i] not in MountFit.MOUNTS:
			r.error("mounts[%d]" % i, "'%s' is not one of %s" % [mounts[i], ", ".join(MountFit.MOUNTS)])
		elif (mounts[i] == "launcher") != (d.kind == "guided"):
			r.error("mounts[%d]" % i, "guided weapons use the launcher mount, and only they do")
		elif mounts[i] not in d.mounts:
			d.mounts.append(mounts[i])
	d.damage_shield = r.number("damage_shield", 0.0, false, 0.0)
	d.damage_armor = r.number("damage_armor", 0.0, false, 0.0)
	d.max_range = r.number("range", 0.0, false, 0.0)
	d.lifetime = r.number("lifetime", 1.0, false, 0.0)
	d.speed = r.number("speed", 600.0, false, 0.0)
	d.reload = r.number("reload", 0.5, false, 0.0)
	d.turn_rate = r.number("turn_rate", 0.0, false, 0.0)
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
