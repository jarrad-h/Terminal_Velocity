extends Node
## Every debug action lives here; the DebugPanel (and later the console) call
## these methods. All commands are no-ops outside debug builds.

signal panel_toggled(panel_visible: bool)
signal time_scale_changed(scale: float)
signal paused_changed(paused: bool)
signal overlay_changed(overlay: StringName, enabled: bool)
## Result of a D8 reload: empty errors means success.
signal data_reload_finished(errors: Array[String])
signal invulnerable_changed(enabled: bool)

## D9 overlays, in panel order.
const OVERLAYS: Array[StringName] = [&"hitboxes", &"velocity", &"ai_labels", &"stats"]

var panel_visible: bool = false
var player_invulnerable: bool = false
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


## D2: swaps the player's hull, keeping position, heading and velocity.
func swap_player_ship(ship_id: String) -> bool:
	if not OS.is_debug_build():
		return false
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	var def: ShipDef = DataRegistry.get_ship(ship_id)
	if player == null or def == null:
		push_error("swap_player_ship: no player or no ship '%s'" % ship_id)
		return false
	player.setup(def)
	return true


## D8: re-reads every data file; live ships and scenery update on success.
func reload_data() -> Array[String]:
	if not OS.is_debug_build():
		return []
	var errors: Array[String] = DataRegistry.reload()
	data_reload_finished.emit(errors)
	return errors


## Switches the current system's backdrop and local space.
func switch_system(system_id: String) -> bool:
	if not OS.is_debug_build():
		return false
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if scene == null:
		return false
	return scene.load_system(system_id)


func current_system_id() -> String:
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if scene == null or scene.system == null:
		return ""
	return scene.system.id


## D4: the player ignores all damage.
func set_player_invulnerable(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	player_invulnerable = enabled
	var player: Ship = _player()
	if player != null:
		player.health.invulnerable = enabled
	invulnerable_changed.emit(enabled)


## D5: drops the player's target to its disable threshold.
func disable_target() -> bool:
	var target: Ship = _player_target()
	if target == null:
		return false
	target.health.force_disable()
	return true


## D5
func destroy_target() -> bool:
	var target: Ship = _player_target()
	if target == null:
		return false
	target.health.force_destroy()
	return true


## D3: spawns `count` ships ahead of the player (game.json debug.spawn_distance),
## optionally under a government. They idle until AI arrives in milestone 4.
func spawn_ships(ship_id: String, count: int = 1, government: String = "") -> Array[Ship]:
	var spawned: Array[Ship] = []
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var player: Ship = _player()
	if not OS.is_debug_build() or scene == null or player == null:
		return spawned
	var distance: float = float(DataRegistry.settings["debug"]["spawn_distance"])
	var ahead: Vector2 = player.global_position + FlightModel.heading(player.global_rotation) * distance
	for i: int in count:
		var offset := Vector2.from_angle(TAU * i / maxf(count, 1)) * (distance * 0.3 if count > 1 else 0.0)
		var ship: Ship = scene.spawn_ship(ship_id, ahead + offset, government)
		if ship == null:
			break
		ship.set_controller(IdleController.new())
		spawned.append(ship)
	return spawned


## D5: removes every ship except the player.
func clear_ships() -> int:
	if not OS.is_debug_build():
		return 0
	var removed: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		if not node.is_in_group(&"player"):
			node.remove_from_group(&"ships")
			node.queue_free()
			removed += 1
	return removed


## D9: player world position and local-space chunk, for the panel readout.
func player_location_text() -> String:
	var player: Ship = _player()
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if player == null or scene == null:
		return "Position: -"
	var chunk: Vector2i = SceneryGen.chunk_of(player.global_position, scene.local_space.chunk_size)
	return "Position (%.0f, %.0f)   Chunk (%d, %d)" % [player.global_position.x, player.global_position.y, chunk.x, chunk.y]


func _player() -> Ship:
	return get_tree().get_first_node_in_group(&"player")


func _player_target() -> Ship:
	var player: Ship = _player()
	if not OS.is_debug_build() or player == null:
		return null
	return player.get_target()
