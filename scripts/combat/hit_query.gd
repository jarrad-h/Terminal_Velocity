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


## C11: damage multiplier for a hit by a shooter whose side was recorded at
## launch (`shooter_is_player`, `shooter_government`), so a missile still
## knows its side after the ship that fired it is gone.
static func damage_scale(shooter_is_player: bool, shooter_government: String, target: Node) -> float:
	if not target is Ship:
		return 1.0
	var to: Ship = target
	var from_gov: GovernmentDef = DataRegistry.get_government(shooter_government) if shooter_government != "" else null
	var pct: float = float(DataRegistry.settings["combat"]["friendly_fire_pct"])
	return Relations.damage_scale(shooter_is_player, from_gov, to.gov_def(), pct)


## Convenience for a live shooter (beams, tests).
static func damage_scale_from(shooter: Ship, target: Node) -> float:
	if shooter == target:
		return 1.0
	return damage_scale(shooter.is_player(), shooter.government, target)
