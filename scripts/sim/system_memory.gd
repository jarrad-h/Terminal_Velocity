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
## EC5: system id -> {port id -> {commodity id -> saturation fraction}};
## absent = 0 (at its tier price).
var markets: Dictionary = {}


## EC5: a port's saturation for a commodity.
func saturation(system_id: String, port_id: String, commodity: String) -> float:
	return float(markets.get(system_id, {}).get(port_id, {}).get(commodity, 0.0))


func set_saturation(system_id: String, port_id: String, commodity: String, amount: float) -> void:
	var ports: Dictionary = markets.get(system_id, {})
	var goods: Dictionary = ports.get(port_id, {})
	if is_zero_approx(amount):
		goods.erase(commodity)
	else:
		goods[commodity] = amount
	if goods.is_empty():
		ports.erase(port_id)
	else:
		ports[port_id] = goods
	if ports.is_empty():
		markets.erase(system_id)
	else:
		markets[system_id] = ports


## EC5: a day of recovery for every market (`economy`: game.json economy).
func recover_markets(economy: Dictionary) -> void:
	for system_id: String in markets.keys():
		for port_id: String in (markets[system_id] as Dictionary).keys():
			for commodity: String in (markets[system_id][port_id] as Dictionary).keys():
				set_saturation(system_id, port_id, commodity, Market.recovered(saturation(system_id, port_id, commodity), 1, economy))


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
			var now: float = value(system_id, name, baseline)
			var fraction: float = float(rule.get("recovery_fraction", 0.0))
			if fraction > 0.0:
				# EC9: closes a share of the gap each day (danger).
				now += (baseline - now) * fraction
				if absf(now - baseline) < 0.05:
					now = baseline
			_store(system_id, name, SystemMemory.recover(now, baseline, float(rule["recovery_per_day"])), baseline)
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
	return {"values": values.duplicate(true), "wrecks": wrecks.duplicate(true), "markets": markets.duplicate(true)}


static func from_dict(data: Dictionary) -> SystemMemory:
	var memory := SystemMemory.new()
	memory.values = (data.get("values", {}) as Dictionary).duplicate(true)
	memory.wrecks = (data.get("wrecks", {}) as Dictionary).duplicate(true)
	memory.markets = (data.get("markets", {}) as Dictionary).duplicate(true)
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


## EC9: a traffic entry's count after danger, by role: traders thin out (by
## at most `trader_cut_max`), patrols are drawn in (at most `patrol_max_extra`).
static func danger_count(count: int, role: String, danger: float, baseline: float, cfg: Dictionary) -> int:
	var over: float = maxf(danger - baseline, 0.0)
	if role == "trader":
		var cut: float = minf(over * float(cfg["trader_cut_per_point"]), float(cfg["trader_cut_max"]))
		return maxi(0, roundi(count * (1.0 - cut)))
	if role == "warship":
		return count + mini(roundi(over * float(cfg["patrol_per_point"])), int(cfg["patrol_max_extra"]))
	return count


## EC9: "low", "medium", "high" or "extreme" (`levels`: the three thresholds).
static func danger_level(danger: float, levels: Array) -> String:
	if danger >= float(levels[2]):
		return "extreme"
	if danger >= float(levels[1]):
		return "high"
	if danger >= float(levels[0]):
		return "medium"
	return "low"

