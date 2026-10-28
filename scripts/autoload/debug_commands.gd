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
signal toggles_changed

## D9 overlays, in panel order.
const OVERLAYS: Array[StringName] = [&"hitboxes", &"velocity", &"ai_labels", &"stats"]

var panel_visible: bool = false
var player_invulnerable: bool = false
## D4: AI ships coast with no input.
var ai_paused: bool = false
## D4: radar shows ships beyond its range on the rim.
var radar_show_all: bool = false
## D10: true while the console has the keyboard (the ship ignores flight keys).
var console_open: bool = false
signal console_toggled(open: bool)
## D3: when set, the next left click in the world spawns there.
var _pending_click_spawn: Callable = Callable()
var _overlays: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		toggle_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_console"):
		toggle_console()
		get_viewport().set_input_as_handled()
	elif _pending_click_spawn.is_valid() and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position
		_pending_click_spawn.call(at)
		_pending_click_spawn = Callable()
		get_viewport().set_input_as_handled()


## D3: the next left click in the world (outside the panel) runs `spawn(at)`.
func spawn_at_next_click(spawn: Callable) -> void:
	if OS.is_debug_build():
		_pending_click_spawn = spawn


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
## `at`: centre of the group; defaults to ahead of the player.
func spawn_ships(ship_id: String, count: int = 1, government: String = "", at: Variant = null) -> Array[Ship]:
	var spawned: Array[Ship] = []
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var player: Ship = _player()
	if not OS.is_debug_build() or scene == null or player == null:
		return spawned
	var distance: float = float(DataRegistry.settings["debug"]["spawn_distance"])
	var ahead: Vector2 = at if at is Vector2 else player.global_position + FlightModel.heading(player.global_rotation) * distance
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


## Debug: traffic on (refills the system now) or off (removes AI traffic).
func set_traffic_enabled(enabled: bool) -> void:
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	if not OS.is_debug_build() or scene == null:
		return
	var traffic: TrafficSpawner = scene.traffic
	traffic.enabled = enabled
	traffic.configure(scene.system, true)
	toggles_changed.emit()


func is_traffic_enabled() -> bool:
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	return scene != null and scene.traffic.enabled


## D4
func set_ai_paused(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	ai_paused = enabled
	toggles_changed.emit()


## D4: radar draws ships beyond its range on the rim.
func set_radar_show_all(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	radar_show_all = enabled
	toggles_changed.emit()


## D3: spawns `count` AI ships from a pool ahead of the player, with their
## pool's behaviour and a personality each; optional government override.
func spawn_pool(pool_id: String, count: int = 1, government: String = "", at: Variant = null) -> Array[Ship]:
	var spawned: Array[Ship] = []
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var player: Ship = _player()
	var pool: AiPoolDef = DataRegistry.get_ai_pool(pool_id)
	if not OS.is_debug_build() or scene == null or player == null or pool == null:
		return spawned
	var distance: float = float(DataRegistry.settings["debug"]["spawn_distance"])
	var ahead: Vector2 = at if at is Vector2 else player.global_position + FlightModel.heading(player.global_rotation) * distance
	for i: int in count:
		var offset := Vector2.from_angle(TAU * i / maxf(count, 1)) * (distance * 0.3 if count > 1 else 0.0)
		var ship: Ship = scene.traffic.spawn_from_pool(pool, ahead + offset, government)
		if ship != null:
			spawned.append(ship)
	return spawned


## D6
func set_credits(value: int) -> void:
	if OS.is_debug_build():
		GameState.set_credits(value)


## D6
func set_record(government: String, value: float) -> void:
	if OS.is_debug_build() and DataRegistry.get_government(government) != null:
		GameState.set_record(government, value)


## D10
func toggle_console() -> void:
	if not OS.is_debug_build():
		return
	console_open = not console_open
	console_toggled.emit(console_open)


## D10: one command line, the same actions as the panel. Returns the reply.
func run_command(line: String) -> String:
	if not OS.is_debug_build():
		return ""
	var w: Array[String] = ConsoleParser.tokenize(line)
	if w.is_empty():
		return ""
	var gov_arg: Callable = func(index: int) -> String: return w[index] if w.size() > index else ""
	match w[0]:
		"help":
			return "Commands: spawn <ship> [n] [gov] | pool <pool> [n] [gov] | swap <ship> | system <id> | reload | " \
				+ "time <scale> | pause | resume | step | invuln on|off | ai on|off | traffic on|off | radar all|range | " \
				+ "kill | disable | clear | credits <n> | record <gov> <n> | overlay <name> on|off | ids <type> | pos"
		"spawn", "pool":
			if w.size() < 2:
				return "Usage: %s <id> [count] [government]" % w[0]
			var count: Variant = ConsoleParser.int_arg(w, 2, 1)
			if count == null:
				return "Count must be a whole number"
			var made: Array[Ship] = spawn_ships(w[1], count, gov_arg.call(3)) if w[0] == "spawn" else spawn_pool(w[1], count, gov_arg.call(3))
			return "Spawned %d" % made.size() if not made.is_empty() else "Nothing spawned (unknown id '%s'?)" % w[1]
		"swap":
			return "Swapped to %s" % w[1] if w.size() > 1 and swap_player_ship(w[1]) else "Usage: swap <ship id>"
		"system":
			return "Switched to %s" % w[1] if w.size() > 1 and switch_system(w[1]) else "Usage: system <system id>"
		"reload":
			var errors: Array[String] = reload_data()
			return "Reloaded" if errors.is_empty() else "Reload failed:\n" + "\n".join(errors)
		"time":
			if w.size() < 2 or not ConsoleParser.is_number(w[1]):
				return "Usage: time <scale>"
			set_time_scale(w[1].to_float())
			return "Time scale %s" % Engine.time_scale
		"pause":
			set_paused(true)
			return "Paused"
		"resume":
			set_paused(false)
			return "Resumed"
		"step":
			step_frame()
			return "Stepped"
		"invuln", "ai", "traffic":
			var on: int = ConsoleParser.parse_switch(w[1]) if w.size() > 1 else -1
			if on == -1:
				return "Usage: %s on|off" % w[0]
			match w[0]:
				"invuln":
					set_player_invulnerable(on == 1)
				"ai":
					set_ai_paused(on == 0)
				"traffic":
					set_traffic_enabled(on == 1)
			return "%s %s" % [w[0], "on" if on == 1 else "off"]
		"radar":
			if w.size() < 2 or w[1] not in ["all", "range"]:
				return "Usage: radar all|range"
			set_radar_show_all(w[1] == "all")
			return "Radar shows %s" % ("all ships" if w[1] == "all" else "ships in range")
		"kill":
			return "Target destroyed" if destroy_target() else "No target"
		"disable":
			return "Target disabled" if disable_target() else "No target"
		"clear":
			return "Removed %d ships" % clear_ships()
		"credits":
			if w.size() < 2 or not ConsoleParser.is_int(w[1]):
				return "Usage: credits <n>"
			set_credits(w[1].to_int())
			return "Credits %d" % GameState.credits
		"record":
			if w.size() < 3 or not ConsoleParser.is_number(w[2]) or DataRegistry.get_government(w[1]) == null:
				return "Usage: record <government id> <n>"
			set_record(w[1], w[2].to_float())
			return "Record with %s: %s" % [w[1], GameState.get_record(w[1])]
		"overlay":
			var on: int = ConsoleParser.parse_switch(w[2]) if w.size() > 2 else -1
			if w.size() < 3 or StringName(w[1]) not in OVERLAYS or on == -1:
				return "Usage: overlay %s on|off" % "|".join(OVERLAYS)
			set_overlay(StringName(w[1]), on == 1)
			return "Overlay %s %s" % [w[1], w[2]]
		"ids":
			if w.size() < 2:
				return "Usage: ids ships|weapons|governments|ai_pools|systems|scenery|personalities"
			return ", ".join(DataRegistry.ids(w[1]))
		"pos":
			return player_location_text()
	return "Unknown command '%s' (try help)" % w[0]


## Restart after "lost with all hands": debug session state goes back to normal.
func reset_session() -> void:
	console_open = false
	ai_paused = false
	radar_show_all = false
	player_invulnerable = false
	_pending_click_spawn = Callable()
	Engine.time_scale = 1.0
