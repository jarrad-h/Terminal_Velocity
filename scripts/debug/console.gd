class_name DebugConsole
extends CanvasLayer
## D10: text console (F1, debug builds only). Every line goes through
## DebugCommands.run_command, the same command layer the panel uses.
## Up arrow recalls the previous command; Esc or F1 closes.

const MAX_LINES: int = 14

var _input: LineEdit
var _output: Label
var _lines: Array[String] = []
var _history: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -320.0
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_output = Label.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_output)
	_input = LineEdit.new()
	_input.placeholder_text = "Type a command (help)"
	_input.text_submitted.connect(_submit)
	_input.gui_input.connect(_on_input_key)
	box.add_child(_input)
	visible = false
	DebugCommands.console_toggled.connect(_on_toggled)


func _on_toggled(open: bool) -> void:
	visible = open
	if open:
		_input.grab_focus()
	else:
		_input.release_focus()


func _submit(line: String) -> void:
	_input.clear()
	if line.strip_edges() == "":
		return
	_history.append(line)
	_print("> " + line)
	_print(DebugCommands.run_command(line))


func _on_input_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_UP:
			if not _history.is_empty():
				_input.text = _history[-1]
				_input.caret_column = _input.text.length()
			_input.accept_event()
		KEY_ESCAPE, KEY_F1:
			DebugCommands.toggle_console()
			_input.accept_event()


func _print(text: String) -> void:
	if text == "":
		return
	_lines.append_array(text.split("\n"))
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_output.text = "\n".join(_lines)
