class_name StellarArt
extends RefCounted
## V9: a stellar's art set (planets, stations, gates, the star), read from the
## manifest beside its sprites. Filled out in milestone 2's lighting slice.


## TR5: where ships leave and arrive at a gate, px from its centre.
static func jump_point(_gate: SystemObjectDef) -> Vector2:
	return Vector2.ZERO
