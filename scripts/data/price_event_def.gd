class_name PriceEventDef
extends Def
## EC2: a temporary price change (data/price_events). Each day it isn't
## running it may start (chance per day, while its condition holds); it then
## lasts a number of days. It applies at ports matching any of `ports`,
## `systems` or `governments` (all empty = everywhere).

var name: String
var commodity: String
## Price multiplier while active (1.6 = +60%).
var factor: float
var days: Vector2i
var chance_per_day: float
var ports: Array[String] = []
var systems: Array[String] = []
var governments: Array[String] = []
## "" always; "flag"; "!flag" (TR6 grammar).
var condition: String
## News when it starts and ends ("" = none).
var news_start: String
var news_end: String


static func parse(r: DefReader) -> PriceEventDef:
	var d := PriceEventDef.new()
	d.name = r.string("name", "", true)
	d.commodity = r.ref("commodity", "commodities", "", true)
	d.factor = r.number("factor", 1.0, true, 0.01)
	var span: Vector2 = r.range2("days", Vector2(5.0, 10.0), 1.0)
	d.days = Vector2i(roundi(span.x), roundi(span.y))
	d.chance_per_day = r.number("chance_per_day", 0.05, false, 0.0)
	if d.chance_per_day > 1.0:
		r.error("chance_per_day", "must be at most 1")
	d.ports = r.string_array("ports")
	d.systems = r.ref_array("systems", "systems")
	d.governments = r.ref_array("governments", "governments")
	d.condition = r.string("condition")
	if not GateRules.is_valid_condition(d.condition):
		r.error("condition", "expected \"\", \"flag_name\" or \"!flag_name\" (lowercase snake_case)")
	d.news_start = r.string("news_start")
	d.news_end = r.string("news_end")
	return d


## Does it apply at this port?
func applies(system_id: String, port_id: String, government: String) -> bool:
	if ports.is_empty() and systems.is_empty() and governments.is_empty():
		return true
	return ports.has(port_id) or systems.has(system_id) or (government != "" and governments.has(government))


## Every port it names must exist in some system.
func validate(defs: Dictionary, errors: Array[String]) -> void:
	var known: Dictionary = {}
	for system: SystemDef in defs.get("systems", {}).values():
		for obj: SystemObjectDef in system.objects:
			known[obj.id] = true
	for port: String in ports:
		if not known.has(port):
			errors.append("%s: field 'ports': no port '%s' in any system" % [file, port])

