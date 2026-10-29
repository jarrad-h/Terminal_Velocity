class_name MountFit
extends RefCounted
## V3: does a weapon item fit a hardpoint? Hardpoints and weapons each have a
## size (small, medium, large) and weapons come in one or more mount types
## (fixed, pivot, turret, launcher); an installed item records which mount it
## was built for. Pure, so the loader now and an outfitter later share it.

const SIZES: Array[String] = ["small", "medium", "large"]
const MOUNTS: Array[String] = ["fixed", "pivot", "turret", "launcher"]


## "" when the item fits, else the reason it doesn't.
static func problem(weapon_size: String, weapon_mounts: Array[String], item_mount: String,
		hardpoint_size: String, hardpoint_mount: String) -> String:
	if item_mount not in weapon_mounts:
		return "the weapon doesn't come in a %s mount (it comes in %s)" % [item_mount, ", ".join(weapon_mounts)]
	if item_mount != hardpoint_mount:
		return "a %s item doesn't fit a %s hardpoint" % [item_mount, hardpoint_mount]
	if weapon_size != hardpoint_size:
		return "a %s weapon doesn't fit a %s hardpoint" % [weapon_size, hardpoint_size]
	return ""


static func fits(weapon_size: String, weapon_mounts: Array[String], item_mount: String,
		hardpoint_size: String, hardpoint_mount: String) -> bool:
	return problem(weapon_size, weapon_mounts, item_mount, hardpoint_size, hardpoint_mount) == ""
