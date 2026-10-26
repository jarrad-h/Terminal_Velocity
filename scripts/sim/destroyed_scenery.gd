class_name DestroyedScenery
extends RefCounted
## L4: in-memory set of destroyed scenery for the current system, keyed by
## (chunk, scenery ID, placement index). Cleared on system change.

var _keys: Dictionary = {}


static func key(chunk: Vector2i, scenery_id: String, index: int) -> String:
	return "%d,%d,%s,%d" % [chunk.x, chunk.y, scenery_id, index]


func add(chunk: Vector2i, scenery_id: String, index: int) -> void:
	_keys[key(chunk, scenery_id, index)] = true


func has(chunk: Vector2i, scenery_id: String, index: int) -> bool:
	return _keys.has(key(chunk, scenery_id, index))


func size() -> int:
	return _keys.size()


func clear() -> void:
	_keys.clear()
