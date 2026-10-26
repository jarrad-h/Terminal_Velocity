class_name DefReader
extends RefCounted
## Reads fields from one parsed JSON object with type checks and defaults.
## Every problem is appended to `errors` as "<file>: field '<path>': <message>".
## References to other definitions are recorded in `refs` for the loader to
## resolve once every file has loaded.

var data: Dictionary
var file: String
var prefix: String
var errors: Array[String]
## Shared with child readers: [{"field": String, "type": String, "id": String}].
var refs: Array[Dictionary]
var _read: Dictionary = {}
var _children: Array[DefReader] = []


func _init(p_data: Dictionary, p_file: String, p_errors: Array[String], p_prefix: String = "", p_refs: Array[Dictionary] = []) -> void:
	data = p_data
	file = p_file
	errors = p_errors
	prefix = p_prefix
	refs = p_refs


func path(key: String) -> String:
	return prefix + key


func error(key: String, message: String) -> void:
	errors.append("%s: field '%s': %s" % [file, path(key), message])


func has(key: String) -> bool:
	return data.has(key)


func _take(key: String, required: bool) -> Variant:
	_read[key] = true
	if not data.has(key):
		if required:
			error(key, "is required")
		return null
	return data[key]


func string(key: String, default: String = "", required: bool = false) -> String:
	var value: Variant = _take(key, required)
	if value == null:
		return default
	if not value is String:
		error(key, "expected text")
		return default
	return value


func number(key: String, default: float = 0.0, required: bool = false, min_value: float = -INF) -> float:
	var value: Variant = _take(key, required)
	if value == null:
		return default
	if not (value is float or value is int):
		error(key, "expected a number")
		return default
	if float(value) < min_value:
		error(key, "must be at least %s" % min_value)
		return default
	return float(value)


func integer(key: String, default: int = 0, required: bool = false, min_value: int = -2147483648) -> int:
	var value: float = number(key, default, required, min_value)
	if value != floorf(value):
		error(key, "expected a whole number")
	return int(value)


func boolean(key: String, default: bool = false) -> bool:
	var value: Variant = _take(key, false)
	if value == null:
		return default
	if not value is bool:
		error(key, "expected true or false")
		return default
	return value


## A choice from a fixed list of words.
func choice(key: String, options: Array[String], default: String = "", required: bool = false) -> String:
	var value: String = string(key, default, required)
	if data.has(key) and value not in options:
		error(key, "'%s' is not one of %s" % [value, ", ".join(options)])
		return default
	return value


## [x, y]
func vec2(key: String, default: Vector2 = Vector2.ZERO, required: bool = false) -> Vector2:
	var value: Variant = _take(key, required)
	if value == null:
		return default
	if not _is_number_pair(value):
		error(key, "expected [x, y]")
		return default
	return Vector2(value[0], value[1])


## [min, max], or a single number meaning [n, n].
func range2(key: String, default: Vector2 = Vector2.ZERO, min_value: float = -INF) -> Vector2:
	var value: Variant = _take(key, false)
	if value == null:
		return default
	if value is float or value is int:
		value = [value, value]
	if not _is_number_pair(value):
		error(key, "expected [min, max] or a single number")
		return default
	var result := Vector2(value[0], value[1])
	if result.x > result.y:
		error(key, "min %s is greater than max %s" % [result.x, result.y])
		return default
	if result.x < min_value:
		error(key, "must be at least %s" % min_value)
		return default
	return result


## "#rrggbb" or "#rrggbbaa".
func colour(key: String, default: Color = Color.WHITE) -> Color:
	var value: Variant = _take(key, false)
	if value == null:
		return default
	if not (value is String and Color.html_is_valid(value)):
		error(key, "expected a colour like \"#88ccff\"")
		return default
	return Color.html(value)


func array(key: String, required: bool = false) -> Array:
	var value: Variant = _take(key, required)
	if value == null:
		return []
	if not value is Array:
		error(key, "expected a list [...]")
		return []
	return value


func string_array(key: String) -> Array[String]:
	var result: Array[String] = []
	var items: Array = array(key)
	for i: int in items.size():
		if items[i] is String:
			result.append(items[i])
		else:
			errors.append("%s: field '%s[%d]': expected text" % [file, path(key), i])
	return result


## A list of objects; returns one child reader per element.
func objects(key: String, required: bool = false) -> Array[DefReader]:
	var result: Array[DefReader] = []
	var items: Array = array(key, required)
	for i: int in items.size():
		var item_path: String = "%s[%d]." % [path(key), i]
		if not items[i] is Dictionary:
			errors.append("%s: field '%s': expected an object {...}" % [file, item_path.trim_suffix(".")])
			continue
		result.append(_child(items[i], item_path))
	return result


## A nested object; missing means an empty object (all defaults).
func object(key: String) -> DefReader:
	var value: Variant = _take(key, false)
	if value == null:
		return _child({}, path(key) + ".")
	if not value is Dictionary:
		error(key, "expected an object {...}")
		return _child({}, path(key) + ".")
	return _child(value, path(key) + ".")


## Text naming another definition of `type` (a data folder: "ships", "weapons"…).
func ref(key: String, type: String, default: String = "", required: bool = false) -> String:
	var id: String = string(key, default, required)
	if id != "":
		refs.append({"field": "%s: field '%s'" % [file, path(key)], "type": type, "id": id})
	return id


func ref_array(key: String, type: String) -> Array[String]:
	var ids: Array[String] = string_array(key)
	for i: int in ids.size():
		refs.append({"field": "%s: field '%s[%d]'" % [file, path(key), i], "type": type, "id": ids[i]})
	return ids


## Reports fields nobody read (usually typos), here and in nested objects.
func finish() -> void:
	for key: Variant in data:
		if not _read.has(key):
			errors.append("%s: field '%s': unknown field (typo?)" % [file, path(str(key))])
	for child: DefReader in _children:
		child.finish()


func _child(child_data: Dictionary, child_prefix: String) -> DefReader:
	var child := DefReader.new(child_data, file, errors, child_prefix, refs)
	_children.append(child)
	return child


func _is_number_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 \
		and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int)
