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
	d.sprite = r.string("sprite")
	d.sound = r.string("sound")
	return d
