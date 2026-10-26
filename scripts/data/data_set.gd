class_name DataSet
extends RefCounted
## Everything one load produced: definitions by type, global settings, errors.

## Type folder ("ships", "weapons"…) -> {id -> Def}.
var defs: Dictionary = {}
var settings: Dictionary = {}
var errors: Array[String] = []
## Files that replaced an earlier definition with the same ID (mod overrides).
var overrides: Array[String] = []


func get_def(type: String, id: String) -> Def:
	return defs.get(type, {}).get(id)


func ids(type: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(defs.get(type, {}).keys())
	result.sort()
	return result
