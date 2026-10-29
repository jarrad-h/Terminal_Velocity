class_name Hud
extends CanvasLayer
## Player panel (H1: ship name, shield and armour, credits, disabled warning),
## target panel (H3), radar (H2), message line (H4) and the boarding bar (C9).

var player: Ship = null:
	set(value):
		player = value
		if radar != null:
			radar.player = value

var radar: Radar
var messages: MessageLine
var target_panel: TargetPanel
## Set by the system scene; boarding progress (C9).
var actions: PlayerActions = null
var _board_bar: ProgressBar

var _ship_name: Label
var _player_shield: ProgressBar
var _player_armor: ProgressBar
var _status: Label
var _credits: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep readouts current behind paused windows
	if not DataRegistry.load_errors.is_empty():
		set_process(false)
		return
	radar = Radar.new()
	add_child(radar)
	messages = MessageLine.new()
	add_child(messages)
	_board_bar = ProgressBar.new()
	_board_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_board_bar.offset_left = -150.0
	_board_bar.offset_right = 150.0
	_board_bar.offset_top = -170.0
	_board_bar.offset_bottom = -150.0
	_board_bar.max_value = 1.0
	_board_bar.show_percentage = false
	_board_bar.visible = false
	add_child(_board_bar)
	radar.configure(DataRegistry.settings["radar"])
	DataRegistry.data_reloaded.connect(func() -> void: radar.configure(DataRegistry.settings["radar"]))
	var colours: Dictionary = DataRegistry.settings["hud"]["colours"]
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -270.0
	box.offset_right = -12.0
	box.offset_top = 12.0
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(box)
	_ship_name = Label.new()
	box.add_child(_ship_name)
	_credits = Label.new()
	box.add_child(_credits)
	_player_shield = make_bar(box, "Shield", Color.html(colours["shield"]), 250.0)
	_player_armor = make_bar(box, "Armour", Color.html(colours["armor"]), 250.0)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color.html(colours["schematic_empty"]))
	box.add_child(_status)
	target_panel = TargetPanel.new()
	box.add_child(target_panel)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_ship_name.text = player.def.name
	_credits.text = "Credits %d" % GameState.credits
	var progress: float = actions.board_progress() if actions != null else -1.0
	_board_bar.visible = progress >= 0.0
	_board_bar.value = maxf(progress, 0.0)
	fill_bar(_player_shield, player.health.shield, player.health.max_shield)
	fill_bar(_player_armor, player.health.armor, player.health.max_armor)
	_status.text = "DISABLED" if player.health.is_disabled and not player.health.is_destroyed else ""
	target_panel.player = player
	target_panel.target = player.get_target()
	target_panel.refresh()


static func fill_bar(bar: ProgressBar, value: float, max_value: float) -> void:
	bar.max_value = maxf(max_value, 0.001)
	bar.value = value
	(bar.get_meta("label") as Label).text = "%s %.0f / %.0f" % [bar.get_meta("name"), value, max_value]


## A labelled bar: "<name> value / max" above a thin fill.
static func make_bar(parent: Control, bar_name: String, colour: Color, width: float) -> ProgressBar:
	var label := Label.new()
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 8.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta("label", label)
	bar.set_meta("name", bar_name)
	parent.add_child(bar)
	return bar
