class_name ShipDef
extends Def
## A hull class (data/ships). Defaults are documented in data/README.md.

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
## V2: capsule hitbox [width, length] in art px (width ≤ length), and its centre
## offset from the sprite centre (hull body only, not ornaments).
var hit_size: Vector2
var hit_offset: Vector2
## C9: credits aboard [min, max] before the AI pool's wealth factor.
var board_credits: Vector2
## V3: weapon hardpoints, positions in art px.
var hardpoints: Array[HardpointDef] = []
## V3: installed weapon items, at most one per hardpoint.
var loadout: Array[LoadoutEntry] = []
## V5: engine exits in art px, and the glow drawn there.
var engines: Array[Vector2] = []
var engine_colour: Color
var engine_size: float
## TR8: fuel capacity, and the fuel one hyperlane jump costs (flat for now;
## Hyperlanes.jump_fuel is the one place the rule lives).
var fuel: float
var jump_fuel: float
## TR2: hyperspace countdown, seconds (outfits will shorten it, OF3).
var jump_countdown: float
## TM2: galaxy-map units covered per day of hyperlane travel.
var jump_speed: float


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
	d.hit_size = r.vec2("hit_size", Vector2(32.0, 32.0))
	if d.hit_size.x <= 0.0 or d.hit_size.y <= 0.0:
		r.error("hit_size", "width and length must be more than 0")
		d.hit_size = Vector2(32.0, 32.0)
	elif d.hit_size.x > d.hit_size.y:
		r.error("hit_size", "width %s is more than length %s (the capsule runs along the hull)" % [d.hit_size.x, d.hit_size.y])
	d.hit_offset = r.vec2("hit_offset", Vector2.ZERO)
	d.board_credits = r.range2("board_credits", Vector2.ZERO, 0.0)
	var ids: Dictionary = {}
	for h: DefReader in r.objects("hardpoints"):
		var hardpoint: HardpointDef = HardpointDef.parse(h)
		if ids.has(hardpoint.id):
			h.error("id", "'%s' is already used by another hardpoint" % hardpoint.id)
		ids[hardpoint.id] = true
		d.hardpoints.append(hardpoint)
	for e: DefReader in r.objects("loadout"):
		d.loadout.append(LoadoutEntry.parse(e))
	var raw_engines: Array = r.array("engines")
	for i: int in raw_engines.size():
		var p: Variant = raw_engines[i]
		if p is Array and p.size() == 2 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int):
			d.engines.append(Vector2(p[0], p[1]))
		else:
			r.error("engines[%d]" % i, "expected [x, y]")
	var glow: DefReader = r.object("engine_glow")
	d.engine_colour = glow.colour("colour", Color.html("#a8d8ff"))
	d.engine_size = glow.number("size", 6.0, false, 0.0)
	d.fuel = r.number("fuel", 300.0, false, 0.0)
	d.jump_fuel = r.number("jump_fuel", 100.0, false, 0.0)
	d.jump_countdown = r.number("jump_countdown", 3.0, false, 0.0)
	d.jump_speed = r.number("jump_speed", 150.0, false, 0.0)
	if r.has("jump_speed") and d.jump_speed <= 0.0:
		r.error("jump_speed", "must be more than 0")
		d.jump_speed = 150.0
	return d


func hardpoint(hardpoint_id: String) -> HardpointDef:
	for h: HardpointDef in hardpoints:
		if h.id == hardpoint_id:
			return h
	return null


## Bounding radius around the sprite centre (flashes, markers), art px.
func bounding_radius() -> float:
	return hit_size.y / 2.0 + hit_offset.length()


## V1: a named sprite must exist (else the game would silently draw a placeholder).
static func sprite_problem(sprite_path: String) -> String:
	if sprite_path == "" or ResourceLoader.exists(Ship.SPRITE_DIR.path_join(sprite_path)):
		return ""
	return "no image at %s" % Ship.SPRITE_DIR.path_join(sprite_path)


## V3, C1: every item names a real hardpoint, at most one item per hardpoint,
## and the weapon fits it (size and mount, MountFit).
func validate(defs: Dictionary, errors: Array[String]) -> void:
	var problem_sprite: String = sprite_problem(sprite)
	if problem_sprite != "":
		errors.append("%s: field 'sprite': %s" % [file, problem_sprite])
	var used: Dictionary = {}
	for i: int in loadout.size():
		var entry: LoadoutEntry = loadout[i]
		var field: String = "%s: field 'loadout[%d]'" % [file, i]
		var h: HardpointDef = hardpoint(entry.hardpoint)
		if h == null:
			errors.append("%s: no hardpoint '%s' on this ship" % [field, entry.hardpoint])
			continue
		if used.has(entry.hardpoint):
			errors.append("%s: hardpoint '%s' already has a weapon" % [field, entry.hardpoint])
		used[entry.hardpoint] = true
		var weapon: WeaponDef = defs["weapons"].get(entry.weapon)
		if weapon == null:
			continue  # reported as a missing reference
		var problem: String = MountFit.problem(weapon.size, weapon.mounts, entry.mount, h.size, h.mount)
		if problem != "":
			errors.append("%s: '%s' on hardpoint '%s': %s" % [field, weapon.id, h.id, problem])
