class_name SceneryDef
extends Def
## A local-space object type (data/scenery): dust, debris, asteroids, wrecks…
## One generic Scenery scene is configured from this; no type-specific code.

const BEHAVIOURS: Array[String] = ["static", "drift"]

var name: String
## Paths under assets/sprites/; one is picked per object. Empty = placeholder shape.
var sprites: Array[String] = []
## Diameter range in px.
var size: Vector2
## Spin range in degrees/s (sign included, so [-20, 20] spins both ways).
var spin: Vector2
## Drift speed range in px/s, random direction. Only used by behaviour "drift".
var drift: Vector2
## Parallax depth range: 1 = moves with the world, <1 further away, >1 closer.
## Only allowed on non-solid scenery.
var depth: Vector2
var solid: bool
var armor: float
## [{"scenery": String, "count": int}] spawned when destroyed (milestone 3).
var fragments: Array[Dictionary] = []
var behaviour: String
## Placeholder art when no sprite exists: a rough polygon.
var colour: Color
var sides: int
## 0 = regular polygon, 1 = very jagged.
var roughness: float
## Width / height; above 1 makes long shapes such as hulls.
var aspect: float


static func parse(r: DefReader) -> SceneryDef:
	var d := SceneryDef.new()
	d.name = r.string("name", "", true)
	d.sprites = r.string_array("sprites")
	d.size = r.range2("size", Vector2(8.0, 8.0), 0.1)
	d.spin = r.range2("spin", Vector2.ZERO)
	d.drift = r.range2("drift", Vector2.ZERO, 0.0)
	d.depth = r.range2("depth", Vector2.ONE, 0.01)
	d.solid = r.boolean("solid", false)
	d.armor = r.number("armor", 0.0, false, 0.0)
	for f: DefReader in r.objects("fragments"):
		d.fragments.append({"scenery": f.ref("scenery", "scenery", "", true), "count": f.integer("count", 1, false, 1)})
	d.behaviour = r.choice("behaviour", BEHAVIOURS, "static")
	var art: DefReader = r.object("placeholder")
	d.colour = art.colour("colour", Color(0.6, 0.6, 0.6))
	d.sides = art.integer("sides", 7, false, 3)
	d.roughness = art.number("roughness", 0.3, false, 0.0)
	d.aspect = art.number("aspect", 1.0, false, 0.05)
	if d.solid and d.depth != Vector2.ONE:
		r.error("depth", "must be 1 for solid scenery (only cosmetic scenery can sit at another depth)")
	return d
