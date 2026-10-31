extends Node
## Player state that survives scene changes: credits (H1), the legal record
## with each government (G2–G3), the date (TM1) and travel (TR1, TR7, TR8).
## Everything here is plain values with to_dict / from_dict for saves (SV1).

signal record_changed(government: String, record: float)
signal credits_changed(credits: int)
## H4: an event for the message line; `kind` picks its colour ("info",
## "combat", "standing", "credits"; game.json messages.colours).
signal message_posted(text: String, kind: String)

## TM3: one galaxy step per day passed (persistent entities, system memory,
## price events and deadlines connect here in later milestones).
signal day_passed(day: int)
## TR6: a flag changed (gates reopen or close).
signal flags_changed

var credits: int = 0
var _records: Dictionary = {}
var clock := DayClock.new()
## TR6 and later missions (MS1): named flags, name -> int (0 = not set).
var flags: Dictionary = {}
## PS6: what each system remembers between visits.
var memory := SystemMemory.new()
var travel := TravelState.new()


func _ready() -> void:
	clock.day_passed.connect(func(day: int) -> void:
		memory.step_day(_memory_rules())  # TM3: systems recover a day at a time
		day_passed.emit(day))
	if DataRegistry.load_errors.is_empty():
		_start_new()


func _start_new() -> void:
	flags.clear()
	flags_changed.emit()
	memory = SystemMemory.new()
	credits = int(DataRegistry.settings["player"]["credits"])
	clock.day = 0
	travel = TravelState.new()
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	travel.current_system = galaxy.start_system
	travel.mark_explored(galaxy.start_system)
	var ship: ShipDef = DataRegistry.get_ship(DataRegistry.settings["player_ship"])
	travel.fuel = ship.fuel


func flag(name: String) -> int:
	return int(flags.get(name, 0))


## Sets a flag; 0 clears it.
func set_flag(name: String, value: int) -> void:
	if value == 0:
		flags.erase(name)
	else:
		flags[name] = value
	flags_changed.emit()


## TM2: actions advance the date; each day steps the galaxy in order (TM3).
func advance_days(days: int) -> void:
	clock.advance(days)


## TM1: "14 Mar 3200".
func date_text() -> String:
	return Calendar.date_text(DataRegistry.settings["calendar"]["start_date"], clock.day)


## TR8: fuel never goes above the ship's capacity or below 0.
func set_fuel(value: float, capacity: float) -> void:
	travel.fuel = clampf(value, 0.0, capacity)


func get_record(government: String) -> float:
	if not _records.has(government):
		return float(DataRegistry.settings["player"]["record"])
	return _records[government]


func set_record(government: String, value: float) -> void:
	var before: float = get_record(government)
	_records[government] = value
	record_changed.emit(government, value)
	var gov: GovernmentDef = DataRegistry.get_government(government)
	match Relations.threshold_crossing(gov, before, value):
		-1:
			post_message("%s now treats you as hostile" % gov.name, "standing")  # G3
		1:
			post_message("%s no longer treats you as hostile" % gov.name, "standing")


func set_credits(value: int) -> void:
	credits = value
	credits_changed.emit(credits)


## G2: charges the player for an act against `target` ("shoot", "disable",
## "board", "kill"), once per ship per kind of act.
func report_player_act(target: Ship, act: String) -> void:
	if target.government == "" or target.player_acts.has(act):
		return
	target.player_acts[act] = true
	var gov: GovernmentDef = DataRegistry.get_government(target.government)
	var before: float = get_record(target.government)
	set_record(target.government, Relations.after_penalty(before, gov, act))
	# PS6: crimes raise the system's alert level.
	var lost: float = before - get_record(target.government)
	if lost > 0.0:
		memory_add(travel.current_system, "alert", lost * float(DataRegistry.settings["memory"]["alert_per_record"]))


## PS6: a ship disabled or destroyed in the current system (`act` "disable" or
## "kill"); pirate losses lower pirate presence. Remembered wrecks coming back
## don't count again.
func ship_lost(ship: Ship, act: String) -> void:
	var settings: Dictionary = DataRegistry.settings["memory"]
	if ship.is_player() or ship.has_meta("wreck") or not ship.government in settings["pirate_governments"]:
		return
	memory_add(travel.current_system, "pirate_presence", -float(settings["pirate_loss"][act]))


## PS6: {"baseline", "recovery_per_day", "max"} for a value in a system.
func memory_rule(system_id: String, name: String) -> Dictionary:
	var rule: Dictionary = (DataRegistry.settings["memory"]["values"][name] as Dictionary).duplicate()
	var system: SystemDef = DataRegistry.get_system(system_id)
	if system != null:
		rule.merge(system.memory.get(name, {}), true)
	return rule


func memory_value(system_id: String, name: String) -> float:
	return memory.value(system_id, name, float(memory_rule(system_id, name)["baseline"]))


func memory_add(system_id: String, name: String, delta: float) -> void:
	var rule: Dictionary = memory_rule(system_id, name)
	memory.add(system_id, name, delta, float(rule["baseline"]), float(rule["max"]))


func _memory_rules() -> Dictionary:
	var rules: Dictionary = {}
	for system_id: String in memory.values:
		rules[system_id] = {}
		for name: String in SystemDef.MEMORY_VALUES:
			rules[system_id][name] = memory_rule(system_id, name)
	return rules


## H4: shows `text` on the message line.
func post_message(text: String, kind: String = "info") -> void:
	message_posted.emit(text, kind)


func add_credits(amount: int) -> void:
	set_credits(credits + amount)


## Fresh start (restart after "lost with all hands").
func reset() -> void:
	_records.clear()
	_start_new()
	credits_changed.emit(credits)


## SV1: everything above as plain values (the saves milestone stores this).
func to_dict() -> Dictionary:
	return {"credits": credits, "records": _records.duplicate(), "day": clock.day, "travel": travel.to_dict(), "flags": flags.duplicate(),
		"memory": memory.to_dict()}


func from_dict(data: Dictionary) -> void:
	credits = int(data.get("credits", 0))
	_records = (data.get("records", {}) as Dictionary).duplicate()
	clock.day = int(data.get("day", 0))
	travel = TravelState.from_dict(data.get("travel", {}))
	flags = (data.get("flags", {}) as Dictionary).duplicate()
	memory = SystemMemory.from_dict(data.get("memory", {}))
	flags_changed.emit()
	credits_changed.emit(credits)


## Copy of every government's record (C10 rescue port choice).
func records() -> Dictionary:
	return _records.duplicate()
