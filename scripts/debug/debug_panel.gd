extends CanvasLayer
## D1 debug panel (backtick). Every control calls DebugCommands; this script
## holds no debug logic of its own. Also shows the D9 stats readout.

const OVERLAY_NAMES: Dictionary = {
	&"hitboxes": "Hitboxes",
	&"velocity": "Velocity vectors",
	&"ai_labels": "AI state labels",
	&"stats": "FPS / ship and scenery count",
}

var _panel: PanelContainer
var _time_label: Label
var _pause_button: Button
var _stats_label: Label
var _overlay_checks: Dictionary = {}
var _ship_select: OptionButton
var _system_select: OptionButton
var _reload_label: Label
var _location_label: Label
var _spawn_count: SpinBox
var _government_select: OptionButton
var _invulnerable_check: CheckBox
var _pool_select: OptionButton
var _toggle_checks: Dictionary = {}
var _credits_spin: SpinBox
var _record_rows: VBoxContainer
var _at_cursor: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build()
	_panel.visible = DebugCommands.panel_visible
	DebugCommands.panel_toggled.connect(_on_panel_toggled)
	DebugCommands.time_scale_changed.connect(func(_s: float) -> void: _refresh())
	DebugCommands.paused_changed.connect(func(_p: bool) -> void: _refresh())
	DebugCommands.overlay_changed.connect(_on_overlay_changed)
	DebugCommands.data_reload_finished.connect(_on_data_reload_finished)
	DataRegistry.data_reloaded.connect(_fill_selects)
	DataRegistry.data_reloaded.connect(_build_record_rows)
	_refresh()


func _process(_delta: float) -> void:
	if _panel.visible:
		_location_label.text = DebugCommands.player_location_text()
	_stats_label.visible = DebugCommands.is_overlay_enabled(&"stats")
	if not _stats_label.visible:
		return
	var text: String = "FPS %d   Ships %d" % [Engine.get_frames_per_second(), get_tree().get_nodes_in_group(&"ships").size()]
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if scene != null and scene.system != null:
		var local_space: LocalSpace = scene.local_space
		text += "   Scenery %d in %d chunks   System %s" % [local_space.object_count(), local_space.loaded_chunks().size(), scene.system.id]
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
	# Scrolls when taller than the window.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(470.0, get_viewport().get_visible_rect().size.y - 60.0)
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_make_label("Debug  ( ` to close )"))
	_location_label = _make_label("")
	box.add_child(_location_label)

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
	box.add_child(_make_label("Data"))
	box.add_child(_make_button("Reload data files", DebugCommands.reload_data))
	_reload_label = _make_label("")
	_reload_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reload_label.custom_minimum_size.x = 320.0
	box.add_child(_reload_label)
	var ship_row := HBoxContainer.new()
	box.add_child(ship_row)
	_ship_select = _make_select()
	ship_row.add_child(_ship_select)
	ship_row.add_child(_make_button("Swap ship", func() -> void:
		DebugCommands.swap_player_ship(_ship_select.get_item_text(_ship_select.selected))
		_fill_selects()))
	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	_spawn_count = SpinBox.new()
	_spawn_count.min_value = 1
	_spawn_count.max_value = 20
	_spawn_count.focus_mode = Control.FOCUS_NONE
	_spawn_count.get_line_edit().focus_mode = Control.FOCUS_NONE
	spawn_row.add_child(_spawn_count)
	_government_select = _make_select()
	_government_select.custom_minimum_size.x = 150.0
	spawn_row.add_child(_government_select)
	spawn_row.add_child(_make_button("Spawn", func() -> void:
		var id: String = _ship_select.get_item_text(_ship_select.selected)
		var count: int = int(_spawn_count.value)
		var gov: String = _selected_government()
		if _at_cursor.button_pressed:
			DebugCommands.spawn_at_next_click(func(at: Vector2) -> void: DebugCommands.spawn_ships(id, count, gov, at))
		else:
			DebugCommands.spawn_ships(id, count, gov)))
	spawn_row.add_child(_make_button("Clear ships", DebugCommands.clear_ships))
	var pool_row := HBoxContainer.new()
	box.add_child(pool_row)
	_pool_select = _make_select()
	pool_row.add_child(_pool_select)
	pool_row.add_child(_make_button("Spawn pool", func() -> void:
		var id: String = _pool_select.get_item_text(_pool_select.selected)
		var count: int = int(_spawn_count.value)
		var gov: String = _selected_government()
		if _at_cursor.button_pressed:
			DebugCommands.spawn_at_next_click(func(at: Vector2) -> void: DebugCommands.spawn_pool(id, count, gov, at))
		else:
			DebugCommands.spawn_pool(id, count, gov)))
	_at_cursor = CheckBox.new()
	_at_cursor.text = "Spawn at cursor (click in space after pressing Spawn)"
	_at_cursor.focus_mode = Control.FOCUS_NONE
	box.add_child(_at_cursor)
	var system_row := HBoxContainer.new()
	box.add_child(system_row)
	_system_select = _make_select()
	system_row.add_child(_system_select)
	system_row.add_child(_make_button("Go to system", func() -> void:
		DebugCommands.switch_system(_system_select.get_item_text(_system_select.selected))
		_fill_selects()))
	system_row.add_child(_make_button("Reveal", func() -> void:
		DebugCommands.reveal_system(_system_select.get_item_text(_system_select.selected))))
	system_row.add_child(_make_button("Refuel", DebugCommands.refuel))
	var days_row := HBoxContainer.new()
	box.add_child(days_row)
	for days: int in [1, 7, 30]:
		days_row.add_child(_make_button("+%d day%s" % [days, "" if days == 1 else "s"], func() -> void: DebugCommands.advance_days(days)))
	_fill_selects()

	box.add_child(HSeparator.new())
	box.add_child(_make_label("Combat"))
	_invulnerable_check = CheckBox.new()
	_invulnerable_check.text = "Player invulnerable"
	_invulnerable_check.focus_mode = Control.FOCUS_NONE
	_invulnerable_check.toggled.connect(DebugCommands.set_player_invulnerable)
	box.add_child(_invulnerable_check)
	DebugCommands.invulnerable_changed.connect(func(on: bool) -> void: _invulnerable_check.set_pressed_no_signal(on))
	box.add_child(_make_toggle("AI paused", DebugCommands.set_ai_paused, func() -> bool: return DebugCommands.ai_paused))
	box.add_child(_make_toggle("Traffic on", DebugCommands.set_traffic_enabled, DebugCommands.is_traffic_enabled))
	box.add_child(_make_toggle("Radar shows all ships", DebugCommands.set_radar_show_all, func() -> bool: return DebugCommands.radar_show_all))
	DebugCommands.toggles_changed.connect(_refresh_toggles)
	var target_row := HBoxContainer.new()
	box.add_child(target_row)
	target_row.add_child(_make_button("Disable target", DebugCommands.disable_target))
	target_row.add_child(_make_button("Destroy target", DebugCommands.destroy_target))

	box.add_child(HSeparator.new())
	box.add_child(_make_label("Player state (D6)"))
	var credits_row := HBoxContainer.new()
	box.add_child(credits_row)
	credits_row.add_child(_make_label("Credits"))
	_credits_spin = _make_spin(0.0, 10000000.0, 100.0)
	_credits_spin.value = GameState.credits
	credits_row.add_child(_credits_spin)
	credits_row.add_child(_make_button("Set", func() -> void: DebugCommands.set_credits(int(_credits_spin.value))))
	_record_rows = VBoxContainer.new()
	box.add_child(_record_rows)
	_build_record_rows()
	GameState.record_changed.connect(func(_g: String, _v: float) -> void: _refresh_record_labels())
	GameState.credits_changed.connect(func(c: int) -> void: _credits_spin.value = c)

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


func _selected_government() -> String:
	return "" if _government_select.selected <= 0 else _government_select.get_item_text(_government_select.selected)


func _make_toggle(text: String, setter: Callable, getter: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = getter.call()
	check.toggled.connect(setter)
	check.set_meta("getter", getter)
	_toggle_checks[text] = check
	return check


func _refresh_toggles() -> void:
	for check: CheckBox in _toggle_checks.values():
		check.set_pressed_no_signal((check.get_meta("getter") as Callable).call())


func _make_spin(min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.focus_mode = Control.FOCUS_NONE
	spin.get_line_edit().focus_mode = Control.FOCUS_NONE
	spin.custom_minimum_size.x = 110.0
	return spin


## D6: one row per government: current record, a value and Set.
func _build_record_rows() -> void:
	for child: Node in _record_rows.get_children():
		child.queue_free()
	for gov_id: String in DataRegistry.ids("governments"):
		var row := HBoxContainer.new()
		_record_rows.add_child(row)
		var label := _make_label("")
		label.custom_minimum_size.x = 230.0
		label.set_meta("government", gov_id)
		row.add_child(label)
		var spin := _make_spin(-1000.0, 1000.0, 5.0)
		spin.value = GameState.get_record(gov_id)
		row.add_child(spin)
		row.add_child(_make_button("Set", func() -> void: DebugCommands.set_record(gov_id, spin.value)))
	_refresh_record_labels()


func _refresh_record_labels() -> void:
	for row: Node in _record_rows.get_children():
		var label: Label = row.get_child(0)
		var gov_id: String = label.get_meta("government", "")
		var gov: GovernmentDef = DataRegistry.get_government(gov_id)
		if gov == null:
			continue
		var record: float = GameState.get_record(gov_id)
		label.text = "%s: %.0f%s" % [gov.name, record, "  (hostile)" if record < gov.crime_threshold else ""]


func _on_overlay_changed(overlay: StringName, enabled: bool) -> void:
	var check: CheckBox = _overlay_checks.get(overlay)
	if check != null:
		check.set_pressed_no_signal(enabled)


func _on_panel_toggled(panel_visible: bool) -> void:
	_panel.visible = panel_visible
	if panel_visible:
		_fill_selects()
		_refresh_toggles()
		_refresh_record_labels()


func _fill_selects() -> void:
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	_fill(_ship_select, DataRegistry.ids("ships"), player.def.id if player != null else "")
	_fill(_system_select, DataRegistry.galaxy().system_ids, DebugCommands.current_system_id())
	var governments: Array[String] = ["(no government)"]
	governments.append_array(DataRegistry.ids("governments"))
	var current_pool: String = "" if _pool_select.selected < 0 else _pool_select.get_item_text(_pool_select.selected)
	var pools: Array[String] = DataRegistry.ids("ai_pools")
	_fill(_pool_select, pools, current_pool if current_pool != "" else (pools[0] if not pools.is_empty() else ""))
	var current: String = "" if _government_select.selected < 0 else _government_select.get_item_text(_government_select.selected)
	_fill(_government_select, governments, current if current != "" else governments[0])


func _fill(select: OptionButton, ids: Array[String], current: String) -> void:
	select.clear()
	for id: String in ids:
		select.add_item(id)
		if id == current:
			select.select(select.item_count - 1)


func _on_data_reload_finished(errors: Array[String]) -> void:
	if errors.is_empty():
		_reload_label.text = "Reloaded OK at %s" % Time.get_time_string_from_system()
	else:
		_reload_label.text = "Reload failed (%d), kept old data:\n%s" % [errors.size(), "\n".join(errors)]


func _refresh() -> void:
	_time_label.text = "Time scale: %s×%s" % [Engine.time_scale, "  (paused)" if get_tree().paused else ""]
	_pause_button.text = "Resume" if get_tree().paused else "Pause"


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_select() -> OptionButton:
	var select := OptionButton.new()
	select.focus_mode = Control.FOCUS_NONE
	select.custom_minimum_size.x = 180.0
	return select


## Buttons never take keyboard focus, so flight keys (and space) stay with the ship.
func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button
