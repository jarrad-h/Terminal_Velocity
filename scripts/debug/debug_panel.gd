extends CanvasLayer
## D1 debug panel (backtick). Every control calls DebugCommands; this script
## holds no debug logic of its own. Also shows the D9 stats readout.

const OVERLAY_NAMES: Dictionary = {
	&"hitboxes": "Hitboxes",
	&"velocity": "Velocity vectors",
	&"ai_labels": "AI state labels",
	&"stats": "FPS / ship count",
}

var _panel: PanelContainer
var _time_label: Label
var _pause_button: Button
var _stats_label: Label
var _overlay_checks: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build()
	_panel.visible = DebugCommands.panel_visible
	DebugCommands.panel_toggled.connect(func(v: bool) -> void: _panel.visible = v)
	DebugCommands.time_scale_changed.connect(func(_s: float) -> void: _refresh())
	DebugCommands.paused_changed.connect(func(_p: bool) -> void: _refresh())
	DebugCommands.overlay_changed.connect(_on_overlay_changed)
	_refresh()


func _process(_delta: float) -> void:
	_stats_label.visible = DebugCommands.is_overlay_enabled(&"stats")
	if not _stats_label.visible:
		return
	var text: String = "FPS %d   Ships %d" % [Engine.get_frames_per_second(), get_tree().get_nodes_in_group(&"ships").size()]
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	if player != null:
		text += "   Speed %.0f / %.0f px/s" % [player.get_velocity().length(), player.body.stats.top_speed]
	_stats_label.text = text


func _build() -> void:
	_stats_label = Label.new()
	_stats_label.position = Vector2(12.0, 8.0)
	add_child(_stats_label)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12.0, 36.0)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	box.add_child(_make_label("Debug  ( ` to close )"))

	_time_label = _make_label("")
	box.add_child(_time_label)
	var scales_row := HBoxContainer.new()
	box.add_child(scales_row)
	for scale: Variant in DataRegistry.settings["debug"]["time_scales"]:
		var s: float = float(scale)
		scales_row.add_child(_make_button("%s×" % s, func() -> void: DebugCommands.set_time_scale(s)))
	var pause_row := HBoxContainer.new()
	box.add_child(pause_row)
	_pause_button = _make_button("Pause", DebugCommands.toggle_pause)
	pause_row.add_child(_pause_button)
	pause_row.add_child(_make_button("Step frame", DebugCommands.step_frame))

	box.add_child(HSeparator.new())
	box.add_child(_make_label("Overlays"))
	for overlay: StringName in DebugCommands.OVERLAYS:
		var check := CheckBox.new()
		check.text = OVERLAY_NAMES[overlay]
		check.focus_mode = Control.FOCUS_NONE
		check.button_pressed = DebugCommands.is_overlay_enabled(overlay)
		check.toggled.connect(func(on: bool) -> void: DebugCommands.set_overlay(overlay, on))
		box.add_child(check)
		_overlay_checks[overlay] = check


func _on_overlay_changed(overlay: StringName, enabled: bool) -> void:
	var check: CheckBox = _overlay_checks.get(overlay)
	if check != null:
		check.set_pressed_no_signal(enabled)


func _refresh() -> void:
	_time_label.text = "Time scale: %s×%s" % [Engine.time_scale, "  (paused)" if get_tree().paused else ""]
	_pause_button.text = "Resume" if get_tree().paused else "Pause"


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


## Buttons never take keyboard focus, so flight keys (and space) stay with the ship.
func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button
