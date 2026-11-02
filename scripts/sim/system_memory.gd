class_name SystemMemory
extends RefCounted
## PS6: what each system remembers between visits: named values (alert level,
## pirate presence) that recover towards a baseline each day, and the wrecks
## the player left there. Plain values with to_dict / from_dict (SV1).

## system id -> {value name -> float}; a value at its baseline isn't stored.
var values: Dictionary = {}
## system id -> [{"ship", "government", "position": [x, y], "rotation",
##   "credits", "looted", "acts": [String], "days_left"}]
var wrecks: Dictionary = {}


func value(system_id: String, name: String, baseline: float) -> float:
	return float(values.get(system_id, {}).get(name, baseline))


## Moves a value by `delta`, kept between 0 and `max_value`.
func add(system_id: String, name: String, delta: float, baseline: float, max_value: float) -> void:
	_store(system_id, name, clampf(value(system_id, name, baseline) + delta, 0.0, max_value), baseline)


## TM3: one day passes. `rules`: system id -> {value name -> {"baseline",
## "recovery_per_day"}}. Values recover towards their baseline; wrecks age and
## are scavenged when their days run out.
func step_day(rules: Dictionary) -> void:
	for system_id: String in values.keys():
		for name: String in (values[system_id] as Dictionary).keys():
			var rule: Dictionary = rules.get(system_id, {}).get(name, {"baseline": 0.0, "recovery_per_day": 0.0})
			var baseline: float = float(rule["baseline"])
			_store(system_id, name, SystemMemory.recover(value(system_id, name, baseline), baseline, float(rule["recovery_per_day"])), baseline)
	for system_id: String in wrecks.keys():
		var kept: Array = []
		for wreck: Dictionary in wrecks[system_id]:
			wreck["days_left"] = int(wreck["days_left"]) - 1
			if wreck["days_left"] > 0:
				kept.append(wreck)
		if kept.is_empty():
			wrecks.erase(system_id)
		else:
			wrecks[system_id] = kept


## `value` moved `rate` towards `baseline`, never past it.
static func recover(current: float, baseline: float, rate: float) -> float:
	return move_toward(current, baseline, maxf(rate, 0.0))


## PS6: a traffic entry's count after its memory value: `count` plus
## (value − baseline) × `per_point`, rounded, never below 0.
static func scaled_count(count: int, current: float, baseline: float, per_point: float) -> int:
	return maxi(0, count + roundi((current - baseline) * per_point))


## Replaces a system's wreck list (when the player leaves it).
func set_wrecks(system_id: String, list: Array) -> void:
	if list.is_empty():
		wrecks.erase(system_id)
	else:
		wrecks[system_id] = list


func wrecks_in(system_id: String) -> Array:
	return wrecks.get(system_id, [])


func to_dict() -> Dictionary:
	return {"values": values.duplicate(true), "wrecks": wrecks.duplicate(true)}


static func from_dict(data: Dictionary) -> SystemMemory:
	var memory := SystemMemory.new()
	memory.values = (data.get("values", {}) as Dictionary).duplicate(true)
	memory.wrecks = (data.get("wrecks", {}) as Dictionary).duplicate(true)
	return memory


func _store(system_id: String, name: String, new_value: float, baseline: float) -> void:
	var system_values: Dictionary = values.get(system_id, {})
	if is_equal_approx(new_value, baseline):
		system_values.erase(name)
	else:
		system_values[name] = new_value
	if system_values.is_empty():
		values.erase(system_id)
	else:
		values[system_id] = system_values
