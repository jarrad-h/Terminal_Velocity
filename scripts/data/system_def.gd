class_name SystemDef
extends Def
## A star system (data/systems): objects, traffic, backdrop and local space.

var name: String
var system_seed: int
var objects: Array[SystemObjectDef] = []
## [{"pool": String, "count": int}]
var traffic: Array[Dictionary] = []
var backdrop: BackdropDef
var local_space: Array[LocalSpaceEntry] = []


static func parse(r: DefReader) -> SystemDef:
	var d := SystemDef.new()
	d.name = r.string("name", "", true)
	d.system_seed = r.integer("seed", 0)
	for o: DefReader in r.objects("objects"):
		d.objects.append(SystemObjectDef.parse(o))
	for t: DefReader in r.objects("traffic"):
		d.traffic.append({"pool": t.ref("pool", "ai_pools", "", true), "count": t.integer("count", 1, false, 0)})
	d.backdrop = BackdropDef.parse(r.object("backdrop"))
	for e: DefReader in r.objects("local_space"):
		d.local_space.append(LocalSpaceEntry.parse(e))
	return d


func validate(_defs: Dictionary, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for o: SystemObjectDef in objects:
		if seen.has(o.id):
			errors.append("%s: field 'objects': object id '%s' is used twice" % [file, o.id])
		seen[o.id] = true
