class_name MessageLine
extends VBoxContainer
## H4 (minimal, pulled into M5): the last few event messages at the bottom of
## the screen, each fading out. Fed by GameState.post_message.

const SHOW_SECONDS: float = 4.0
const FADE_SECONDS: float = 1.0
const MAX_LINES: int = 3


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


func show_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_meta("age", 0.0)
	add_child(label)
	while get_child_count() > MAX_LINES:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func _process(delta: float) -> void:
	for label: Node in get_children():
		var age: float = float(label.get_meta("age")) + delta
		label.set_meta("age", age)
		(label as Label).modulate.a = clampf(1.0 - (age - SHOW_SECONDS) / FADE_SECONDS, 0.0, 1.0)
		if age > SHOW_SECONDS + FADE_SECONDS:
			label.queue_free()


func latest() -> String:
	return (get_child(get_child_count() - 1) as Label).text if get_child_count() > 0 else ""
