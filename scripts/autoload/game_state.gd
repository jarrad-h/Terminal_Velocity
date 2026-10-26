extends Node
## Player state that survives scene changes: credits (H1) and the legal record
## with each government (G2–G3), plus which governments the player has
## provoked during this visit to the system (A8).

signal record_changed(government: String, record: float)
signal credits_changed(credits: int)

var credits: int = 0
var _records: Dictionary = {}
var _provoked: Dictionary = {}


func _ready() -> void:
	if DataRegistry.load_errors.is_empty():
		var player: Dictionary = DataRegistry.settings["player"]
		credits = int(player["credits"])


func get_record(government: String) -> float:
	if not _records.has(government):
		return float(DataRegistry.settings["player"]["record"])
	return _records[government]


func set_record(government: String, value: float) -> void:
	_records[government] = value
	record_changed.emit(government, value)


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
	set_record(target.government, Relations.after_penalty(get_record(target.government), gov, act))


## A8: the government's warships treat the player as hostile this visit.
func provoke(government: String) -> void:
	_provoked[government] = true


func is_provoked(government: String) -> bool:
	return _provoked.has(government)


## A8: leaving the system forgets provocations (records persist).
func clear_system_state() -> void:
	_provoked.clear()
