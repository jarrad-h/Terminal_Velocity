class_name Hud
extends CanvasLayer
## Minimal HUD for milestone 3: player shield/armour (H1), the selected
## target's name, shield and armour (C8) and the radar (H2). Polished in M6.

var player: Ship = null:
	set(value):
		player = value
		if radar != null:
			radar.player = value

var radar: Radar
var messages: MessageLine

var _player_shield: ProgressBar
var _player_armor: ProgressBar
var _status: Label
var _credits: Label
var _target_box: VBoxContainer
var _target_name: Label
var _target_shield: ProgressBar
var _target_armor: ProgressBar


func _ready() -> void:
	layer = 10
	if not DataRegistry.load_errors.is_empty():
		set_process(false)
		return
	radar = Radar.new()
	add_child(radar)
	messages = MessageLine.new()
	add_child(messages)
	radar.configure(DataRegistry.settings["radar"])
	DataRegistry.data_reloaded.connect(func() -> void: radar.configure(DataRegistry.settings["radar"]))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -240.0
	box.offset_right = -12.0
	box.offset_top = 12.0
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(box)
	box.add_child(_label("Your ship"))
	_credits = _label("")
	box.add_child(_credits)
	_player_shield = _bar(box, "Shield", Color(0.35, 0.6, 1.0))
	_player_armor = _bar(box, "Armour", Color(0.9, 0.6, 0.3))
	_status = _label("")
	box.add_child(_status)
	_target_box = VBoxContainer.new()
	box.add_child(_target_box)
	_target_name = _label("")
	_target_box.add_child(_target_name)
	_target_shield = _bar(_target_box, "Shield", Color(0.35, 0.6, 1.0))
	_target_armor = _bar(_target_box, "Armour", Color(0.9, 0.6, 0.3))


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_credits.text = "Credits %d" % GameState.credits
	_fill(_player_shield, player.health.shield, player.health.max_shield)
	_fill(_player_armor, player.health.armor, player.health.max_armor)
	_status.text = "DISABLED" if player.health.is_disabled and not player.health.is_destroyed else ""
	var target: Ship = player.get_target()
	_target_box.visible = target != null
	if target == null:
		return
	var state: String = "  (disabled)" if target.health.is_disabled else ""
	_target_name.text = "Target: %s%s  %.0f px" % [target.def.name, state, target.global_position.distance_to(player.global_position)]
	_fill(_target_shield, target.health.shield, target.health.max_shield)
	_fill(_target_armor, target.health.armor, target.health.max_armor)


func _fill(bar: ProgressBar, value: float, max_value: float) -> void:
	bar.max_value = maxf(max_value, 0.001)
	bar.value = value
	(bar.get_meta("label") as Label).text = "%s %.0f / %.0f" % [bar.get_meta("name"), value, max_value]


func _bar(parent: Control, bar_name: String, colour: Color) -> ProgressBar:
	var label := _label("")
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220.0, 8.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta("label", label)
	bar.set_meta("name", bar_name)
	parent.add_child(bar)
	return bar


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
