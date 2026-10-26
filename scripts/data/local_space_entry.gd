class_name LocalSpaceEntry
extends Resource
## L3: one scenery type a system uses, with its density and region.

const REGIONS: Array[String] = ["whole", "ring", "circle"]

var scenery: String
## Objects per 1,000,000 px² (a 1000 × 1000 px area) inside the region.
var density: float
var region: String
var centre: Vector2
## Circle radius, or the ring's outer radius.
var radius: float
## Ring only.
var inner_radius: float


static func create(p_scenery: String, p_density: float, p_region: String = "whole", p_centre: Vector2 = Vector2.ZERO, p_radius: float = 0.0, p_inner_radius: float = 0.0) -> LocalSpaceEntry:
	var e := LocalSpaceEntry.new()
	e.scenery = p_scenery
	e.density = p_density
	e.region = p_region
	e.centre = p_centre
	e.radius = p_radius
	e.inner_radius = p_inner_radius
	return e


static func parse(r: DefReader) -> LocalSpaceEntry:
	var e := LocalSpaceEntry.new()
	e.scenery = r.ref("scenery", "scenery", "", true)
	e.density = r.number("density", 0.0, true, 0.0)
	var region: DefReader = r.object("region")
	e.region = region.choice("shape", REGIONS, "whole")
	e.centre = region.vec2("centre", Vector2.ZERO)
	e.radius = region.number("radius", 0.0, e.region != "whole", 0.0)
	e.inner_radius = region.number("inner_radius", 0.0, e.region == "ring", 0.0)
	if e.region == "ring" and e.inner_radius >= e.radius:
		region.error("inner_radius", "must be smaller than radius")
	return e


func contains(point: Vector2) -> bool:
	match region:
		"circle":
			return point.distance_squared_to(centre) <= radius * radius
		"ring":
			var d2: float = point.distance_squared_to(centre)
			return d2 >= inner_radius * inner_radius and d2 <= radius * radius
	return true
