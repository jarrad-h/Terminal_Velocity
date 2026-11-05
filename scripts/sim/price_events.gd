class_name PriceEvents
extends RefCounted
## EC2: which price events are running. Pure: definitions, the day, flags and
## a random source come in; news lines come out. Saved (SV1).

## event id -> the last day it runs
var active: Dictionary = {}


## TM3: one day passes: finished events end, idle ones may start.
## `defs`: [PriceEventDef]. Returns news lines.
func step_day(defs: Array, day: int, flags: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var news: Array[String] = []
	for id: String in active.keys():
		if day > int(active[id]):
			active.erase(id)
			var ended: PriceEventDef = _find(defs, id)
			if ended != null and ended.news_end != "":
				news.append(ended.news_end)
	for def: PriceEventDef in defs:
		if active.has(def.id) or not GateRules.is_open(def.condition, flags):
			continue
		if rng.randf() < def.chance_per_day:
			start(def, day, rng)
			if def.news_start != "":
				news.append(def.news_start)
	return news


## Starts `def` now (also D16 `event`).
func start(def: PriceEventDef, day: int, rng: RandomNumberGenerator) -> void:
	active[def.id] = day + rng.randi_range(def.days.x, def.days.y) - 1


## EC2: the combined multiplier for a commodity at a port (stacked events multiply).
func factor(defs: Array, system_id: String, port_id: String, government: String, commodity: String) -> float:
	var out: float = 1.0
	for def: PriceEventDef in defs:
		if active.has(def.id) and def.commodity == commodity and def.applies(system_id, port_id, government):
			out *= def.factor
	return out


## Active events that touch this port: [PriceEventDef].
func at_port(defs: Array, system_id: String, port_id: String, government: String) -> Array:
	return defs.filter(func(d: PriceEventDef) -> bool: return active.has(d.id) and d.applies(system_id, port_id, government))


func to_dict() -> Dictionary:
	return {"active": active.duplicate()}


static func from_dict(data: Dictionary) -> PriceEvents:
	var events := PriceEvents.new()
	var raw: Dictionary = data.get("active", {})
	for id: String in raw:
		events.active[id] = int(raw[id])
	return events


static func _find(defs: Array, id: String) -> PriceEventDef:
	for def: PriceEventDef in defs:
		if def.id == id:
			return def
	return null
