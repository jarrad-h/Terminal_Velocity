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
## A6: traffic arrives and leaves at this distance from the system centre, px.
var edge_radius: float
## A6: seconds before replacing a ship that left or died.
var respawn_delay: Vector2
## TR2: a hyperlane jump needs the ship at least this far from the centre;
## TR4: arrivals appear at this distance, px.
var jump_radius: float


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
	d.edge_radius = r.number("edge_radius", 6000.0, false, 100.0)
	d.respawn_delay = r.range2("respawn_delay", Vector2(5.0, 15.0), 0.0)
	d.jump_radius = r.number("jump_radius", 8000.0, false, 100.0)
	return d


func validate(_defs: Dictionary, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for o: SystemObjectDef in objects:
		if seen.has(o.id):
			errors.append("%s: field 'objects': object id '%s' is used twice" % [file, o.id])
		seen[o.id] = true
	var pools: Dictionary = {}
	for i: int in traffic.size():
		var pool_id: String = traffic[i]["pool"]
		if pools.has(pool_id):
			errors.append("%s: field 'traffic[%d].pool': '%s' is already listed; use one entry with a higher count" % [file, i, pool_id])
		pools[pool_id] = true
