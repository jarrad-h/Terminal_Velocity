class_name HardpointDef
extends RefCounted
## V3: one weapon hardpoint on a hull, positions in art pixels (× art_scale at
## runtime), ship facing up, +x starboard, +y aft.

const ROLES: Array[String] = ["", "point_defence"]

var id: String
var size: String
var mount: String
var pos: Vector2
## Total arc in degrees; < 0 means the mount type's default (game.json mounts.arc).
var arc: float = -1.0
## Degrees/s; < 0 means the mount type's default (game.json mounts.traverse).
var traverse: float = -1.0
## "" or "point_defence" (C13: PD sprite now, PD behaviour later).
var role: String = ""


static func parse(r: DefReader) -> HardpointDef:
	var h := HardpointDef.new()
	h.id = r.string("id", "", true)
	h.size = r.choice("size", MountFit.SIZES, "small", true)
	h.mount = r.choice("mount", MountFit.MOUNTS, "fixed", true)
	h.pos = r.vec2("pos", Vector2.ZERO, true)
	if r.has("arc"):
		h.arc = r.number("arc", -1.0, false, 0.0)
		if h.arc > 360.0:
			r.error("arc", "must be at most 360")
	if r.has("traverse"):
		h.traverse = r.number("traverse", -1.0, false, 0.0)
	h.role = r.choice("role", ROLES, "")
	if h.role == "point_defence" and h.mount != "turret":
		r.error("role", "point_defence needs a turret mount")
	return h


## Arc and traverse after mount-type defaults from game.json `mounts`.
func arc_degrees(settings: Dictionary) -> float:
	if mount == "fixed":
		return 0.0
	if arc >= 0.0:
		return arc
	return float(settings["mounts"]["arc"].get(mount, 360.0))


func traverse_degrees(settings: Dictionary) -> float:
	if traverse >= 0.0:
		return traverse
	return float(settings["mounts"]["traverse"].get(mount, 0.0))
