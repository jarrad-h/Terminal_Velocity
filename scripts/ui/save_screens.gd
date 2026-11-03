class_name SaveScreens
extends RefCounted
## SV2, SV3: the screens for pilots and saves, shared by the main menu and the
## landed screen. Each is a Dialog (shared theme, choices top to bottom).


## SV2: name a new manual save, or overwrite one of the pilot's slots.
static func open_save(parent: Node, on_done: Callable = Callable()) -> Dialog:
	var dialog := Dialog.open(parent, "Save", "")
	dialog.use_shared_theme()
	var slots: Array[Dictionary] = Pilots.list_slots(Pilots.pilot_id).filter(
		func(m: Dictionary) -> bool: return m["id"] != PilotSave.AUTOSAVE and m["id"] != PilotSave.IRONMAN)
	var full: bool = slots.size() >= Pilots.max_slots()
	dialog.set_body("%d of %d save slots used.%s" % [slots.size(), Pilots.max_slots(),
		" All are used: overwrite one." if full else " Name a new save, or overwrite one."])
	var field: LineEdit = null
	if not full:
		field = dialog.add_field("Save name", GameState.date_text())
		dialog.add_choice("new", "Save as new", func() -> void:
			_finish(dialog, Pilots.save_manual(field.text), on_done))
	for meta: Dictionary in slots:
		var slot_name: String = str(meta.get("slot", meta["id"]))
		dialog.add_choice("over_" + str(meta["id"]), "Overwrite: %s" % describe(meta), func() -> void:
			_finish(dialog, Pilots.save_manual(slot_name, true), on_done))
	dialog.add_choice("back", "Back", func() -> void: dialog.close())
	return dialog


static func _finish(dialog: Dialog, error: String, on_done: Callable) -> void:
	if error != "":
		dialog.set_body(error)
		return
	GameState.post_message("Game saved")
	dialog.close()
	if on_done.is_valid():
		on_done.call()


## SV2: one pilot's saves to load; a dead pilot shows its memorial (SV3).
static func open_pilot(parent: Node, entry: Dictionary, on_back: Callable = Callable(), allow_delete: bool = true) -> Dialog:
	var block: Dictionary = entry["pilot"]
	var dialog := Dialog.open(parent, str(block.get("name", entry["id"])), "")
	dialog.use_shared_theme()
	var kind: String = "Ironman pilot" if bool(block.get("ironman", false)) else "Pilot"
	if bool(block.get("dead", false)):
		dialog.set_body("%s, lost with all hands.\n\nIn memoriam. (Their full record arrives with progression.)" % kind)
	else:
		var slots: Array = entry["slots"].filter(func(m: Dictionary) -> bool: return PilotSave.can_load(block, m["id"]))
		dialog.set_body("%s. %s" % [kind, "Pick a save to load." if not slots.is_empty() else "No saves yet."])
		for meta: Dictionary in slots:
			var slot: String = meta["id"]
			dialog.add_choice("load_" + slot, describe(meta), func() -> void:
				var error: String = Pilots.load_save(entry["id"], slot)
				if error != "":
					dialog.set_body(error))
	if allow_delete:
		dialog.add_choice("delete", "Delete pilot", func() -> void:
			_confirm_delete(parent, dialog, entry, on_back))
	dialog.add_choice("back", "Back", func() -> void:
		dialog.close()
		if on_back.is_valid():
			on_back.call())
	return dialog


static func _confirm_delete(parent: Node, pilot_dialog: Dialog, entry: Dictionary, on_back: Callable) -> void:
	var confirm := Dialog.open(parent, "Delete %s?" % entry["pilot"].get("name", entry["id"]), "Every save of this pilot is deleted. This can't be undone.")
	confirm.use_shared_theme()
	confirm.add_choice("yes", "Delete", func() -> void:
		Pilots.delete_pilot(entry["id"])
		confirm.close()
		pilot_dialog.close()
		if on_back.is_valid():
			on_back.call())
	confirm.add_choice("no", "Keep", func() -> void: confirm.close())


## One line for a save in a list.
static func describe(meta: Dictionary) -> String:
	var where: String = Hyperspace.system_name(str(meta.get("system", "")))
	var date: String = Calendar.date_text(DataRegistry.settings["calendar"]["start_date"], int(meta.get("day", 0)))
	return "%s — %s, %s, %d cr  (%s)" % [str(meta.get("slot", meta["id"])), where, date, int(meta.get("credits", 0)),
		str(meta.get("saved_at", "")).replace("T", " ")]
