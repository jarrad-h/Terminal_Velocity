class_name LoadoutEntry
extends RefCounted
## V3: one installed weapon item: which hardpoint, which weapon, and the mount
## type the item was built for (bought by mount type later).

var hardpoint: String
var weapon: String
var mount: String


static func parse(r: DefReader) -> LoadoutEntry:
	var e := LoadoutEntry.new()
	e.hardpoint = r.string("hardpoint", "", true)
	e.weapon = r.ref("weapon", "weapons", "", true)
	e.mount = r.choice("mount", MountFit.MOUNTS, "fixed", true)
	return e
