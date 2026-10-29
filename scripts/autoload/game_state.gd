extends Node
## Player state that survives scene changes: credits (H1) and the legal record
## with each government (G2–G3).

signal record_changed(government: String, record: float)
signal credits_changed(credits: int)
## H4: an event for the message line; `kind` picks its colour ("info",
## "combat", "standing", "credits"; game.json messages.colours).
signal message_posted(text: String, kind: String)

var credits: int = 0
var _records: Dictionary = {}


func _ready() -> void:
	if DataRegistry.load_errors.is_empty():
		var player: Dictionary = DataRegistry.settings["player"]
		credits = int(player["credits"])


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
	set_record(target.government, Relations.after_penalty(get_record(target.government), gov, act))


## H4: shows `text` on the message line.
func post_message(text: String, kind: String = "info") -> void:
	message_posted.emit(text, kind)


func add_credits(amount: int) -> void:
	set_credits(credits + amount)


## Fresh start (restart after "lost with all hands").
func reset() -> void:
	_records.clear()
	credits = int(DataRegistry.settings["player"]["credits"])
	credits_changed.emit(credits)


## Copy of every government's record (C10 rescue port choice).
func records() -> Dictionary:
	return _records.duplicate()
