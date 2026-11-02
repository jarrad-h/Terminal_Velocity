extends Control
## SV2, SV3: the boot screen. Continue the newest save, make a new pilot (name,
## ironman), load any pilot's save, or quit. Pilots and saves live in the
## Pilots autoload; the screens are Dialogs (shared theme).

var _dialog: Dialog = null


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.04)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	if not DataRegistry.load_errors.is_empty():
		_open("Data errors", "\n".join(DataRegistry.load_errors))
		return
	show_main()


func _open(title: String, body: String) -> Dialog:
	if _dialog != null:
		_dialog.close()
	_dialog = Dialog.open(self, title, body)
	_dialog.use_shared_theme()
	return _dialog


func show_main() -> void:
	var pilots: Array[Dictionary] = Pilots.list_pilots()
	var d: Dialog = _open("Terminal Velocity", "%d of %d pilots." % [pilots.size(), Pilots.max_pilots()])
	var latest: Dictionary = Pilots.latest()
	if not latest.is_empty():
		var entry: Dictionary = pilots.filter(func(e: Dictionary) -> bool: return e["id"] == latest["id"])[0]
		var meta: Dictionary = entry["slots"].filter(func(m: Dictionary) -> bool: return m["id"] == latest["slot"])[0]
		d.add_choice("continue", "Continue: %s — %s" % [entry["pilot"].get("name", ""), SaveScreens.describe(meta)], func() -> void:
			_report(Pilots.load_save(latest["id"], latest["slot"])))
	d.add_choice("new", "New pilot", show_new, PilotSave.can_create_pilot(pilots.size(), Pilots.max_pilots()))
	d.add_choice("load", "Load", show_load, not pilots.is_empty())
	d.add_choice("quit", "Quit", func() -> void: get_tree().quit())


func show_new() -> void:
	var d: Dialog = _open("New pilot", "Choose a name. An ironman pilot has one save, written automatically on every landing and jump, and can never go back to an earlier state. This can't be changed later.")
	var field: LineEdit = d.add_field("Pilot name")
	var iron: CheckBox = d.add_check("Ironman")
	d.add_choice("create", "Create pilot", func() -> void:
		var error: String = Pilots.create_pilot(field.text, iron.button_pressed)
		if error != "":
			d.set_body(error)
			return
		_dialog.close()
		get_tree().paused = false
		get_tree().change_scene_to_file(Pilots.SYSTEM_SCENE))
	d.add_choice("back", "Back", show_main)


func show_load() -> void:
	var d: Dialog = _open("Load", "Pick a pilot.")
	for entry: Dictionary in Pilots.list_pilots():
		var block: Dictionary = entry["pilot"]
		var label: String = str(block.get("name", entry["id"]))
		if bool(block.get("ironman", false)):
			label += " (ironman)"
		if bool(block.get("dead", false)):
			label += " — in memoriam"
		else:
			label += " — %d save%s" % [entry["slots"].size(), "" if entry["slots"].size() == 1 else "s"]
		d.add_choice("pilot_" + str(entry["id"]), label, func() -> void:
			_dialog.close()
			_dialog = SaveScreens.open_pilot(self, entry, show_load))
	d.add_choice("back", "Back", show_main)


func _report(error: String) -> void:
	if error != "" and _dialog != null:
		_dialog.set_body(error)
