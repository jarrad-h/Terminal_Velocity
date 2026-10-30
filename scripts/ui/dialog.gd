class_name Dialog
extends CanvasLayer
## A modal window that pauses the game while open: the landed screen (S3),
## the boarding window (C9) and the rescue report (C10). Choices are buttons;
## number keys 1–9 pick them too, keyboard first.

signal closed

## H5: the shared look for new screens (the Amber Glass restyle changes this file).
const THEME_PATH: String = "res://assets/ui/theme.tres"

var _title: Label
var _body: Label
var _buttons: BoxContainer
var _panel: PanelContainer
var _choices: Array[Dictionary] = []  # {"id", "button", "action"}
var _was_paused: bool = false


static func open(parent: Node, title: String, body: String) -> Dialog:
	var dialog := Dialog.new()
	parent.add_child(dialog)
	dialog.set_title(title)
	dialog.set_body(body)
	return dialog


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	_panel = panel
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(520.0, 0.0)
	box.add_child(_body)
	_buttons = BoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true


## H5: new screens use the shared theme and list their choices top to bottom.
func use_shared_theme(vertical_choices: bool = true) -> void:
	_panel.theme = load(THEME_PATH)
	_buttons.vertical = vertical_choices


func set_title(text: String) -> void:
	_title.text = text


func set_body(text: String) -> void:
	_body.text = text


## Adds a choice. `action` runs when it is picked; the dialog stays open unless
## the action closes it.
func add_choice(id: String, text: String, action: Callable, enabled: bool = true) -> void:
	var button := Button.new()
	button.text = "%d  %s" % [_choices.size() + 1, text]
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: choose(id))
	_buttons.add_child(button)
	_choices.append({"id": id, "button": button, "action": action})


func clear_choices() -> void:
	for choice: Dictionary in _choices:
		(choice["button"] as Button).queue_free()
	_choices.clear()


func has_choice(id: String) -> bool:
	return _choices.any(func(c: Dictionary) -> bool: return c["id"] == id and not (c["button"] as Button).disabled)


## Picks a choice by id (also used by tests). False if missing or disabled.
func choose(id: String) -> bool:
	for choice: Dictionary in _choices:
		if choice["id"] == id and not (choice["button"] as Button).disabled:
			(choice["action"] as Callable).call()
			return true
	return false


func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if DebugCommands.console_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = (event as InputEventKey).keycode - KEY_1
		if index >= 0 and index < _choices.size():
			choose(_choices[index]["id"])
			get_viewport().set_input_as_handled()
