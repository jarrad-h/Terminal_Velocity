class_name HitQuery
extends RefCounted
## Finds what a shot or beam segment hits: the first ship or solid-scenery
## hitbox (Area2D) along a line. Anything hit has a `health` (Health).

## Physics layers 1 (ships) and 2 (scenery).
const MASK: int = 0b11


## Returns {"target": Node, "position": Vector2} or {} for no hit.
static func ray(world_node: Node2D, from: Vector2, to: Vector2, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, MASK, exclude)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	var hit: Dictionary = world_node.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var owner: Node = (hit["collider"] as Node).get_parent()
	if owner == null or not "health" in owner or owner.health == null:
		return {}
	return {"target": owner, "position": hit["position"]}


## C11: damage multiplier for `shooter` hitting `target` (game.json combat.friendly_fire_pct).
static func damage_scale(shooter: Variant, target: Node) -> float:
	if not is_instance_valid(shooter) or not shooter is Ship or not target is Ship or shooter == target:
		return 1.0
	var from: Ship = shooter
	var to: Ship = target
	var pct: float = float(DataRegistry.settings["combat"]["friendly_fire_pct"])
	return Relations.damage_scale(from.is_player(), from.gov_def(), to.gov_def(), pct)
