class_name SceneryPlacement
extends RefCounted
## One generated scenery object: where it is and how it moves.

var scenery_id: String
var position: Vector2
## Diameter in px.
var size: float
var rotation: float
## Radians per second.
var spin: float
var velocity: Vector2
var depth: float
## Seed for the object's own look (sprite pick, placeholder shape).
var look_seed: int
