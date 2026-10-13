extends Node
## Every debug action lives here; the DebugPanel (and later the console) call
## these methods. All commands are no-ops outside debug builds.

signal panel_toggled(panel_visible: bool)
signal time_scale_changed(scale: float)
signal paused_changed(paused: bool)
signal overlay_changed(overlay: StringName, enabled: bool)

## D9 overlays, in panel order.
const OVERLAYS: Array[StringName] = [&"hitboxes", &"velocity", &"ai_labels", &"stats"]

var panel_visible: bool = false
var _overlays: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		toggle_panel()
		get_viewport().set_input_as_handled()


## D1
func toggle_panel() -> void:
	if not OS.is_debug_build():
		return
	panel_visible = not panel_visible
	panel_toggled.emit(panel_visible)


## D7: clamped to the range of game.json "debug.time_scales".
func set_time_scale(scale: float) -> void:
	if not OS.is_debug_build():
		return
	var scales: Array = DataRegistry.settings["debug"]["time_scales"]
	Engine.time_scale = clampf(scale, scales.min(), scales.max())
	time_scale_changed.emit(Engine.time_scale)


## D7
func set_paused(paused: bool) -> void:
	if not OS.is_debug_build():
		return
	get_tree().paused = paused
	paused_changed.emit(paused)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


## D7: advances exactly one physics frame while paused.
func step_frame() -> void:
	if not OS.is_debug_build() or not get_tree().paused:
		return
	get_tree().paused = false
	await get_tree().physics_frame  # resumes just before this frame's physics runs
	await get_tree().physics_frame  # that frame has run; stop before the next
	get_tree().paused = true


## D9
func set_overlay(overlay: StringName, enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	_overlays[overlay] = enabled
	overlay_changed.emit(overlay, enabled)


func is_overlay_enabled(overlay: StringName) -> bool:
	return _overlays.get(overlay, false)
