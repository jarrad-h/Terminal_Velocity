class_name MessageLine
extends VBoxContainer
## H4: the last few event messages at the bottom of the screen, each fading
## out, coloured by kind. Fed by GameState.post_message; timing and colours
## come from game.json "messages".


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -400.0
	offset_right = 400.0
	offset_top = -140.0
	offset_bottom = -60.0
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.message_posted.connect(show_message)


func _settings() -> Dictionary:
	return DataRegistry.settings["messages"]


func show_message(text: String, kind: String = "info") -> void:
	var colours: Dictionary = _settings()["colours"]
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.html(colours.get(kind, colours["info"])))
	label.set_meta("age", 0.0)
	label.set_meta("kind", kind)
	add_child(label)
	while get_child_count() > int(_settings()["max_lines"]):
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func _process(delta: float) -> void:
	var show_seconds: float = float(_settings()["show_seconds"])
	var fade_seconds: float = maxf(float(_settings()["fade_seconds"]), 0.001)
	for label: Node in get_children():
		var age: float = float(label.get_meta("age")) + delta
		label.set_meta("age", age)
		(label as Label).modulate.a = clampf(1.0 - (age - show_seconds) / fade_seconds, 0.0, 1.0)
		if age > show_seconds + fade_seconds:
			remove_child(label)
			label.queue_free()


func latest() -> String:
	return (get_child(get_child_count() - 1) as Label).text if get_child_count() > 0 else ""


## Kind of the newest message ("" when empty).
func latest_kind() -> String:
	return String(get_child(get_child_count() - 1).get_meta("kind")) if get_child_count() > 0 else ""
