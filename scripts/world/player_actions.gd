class_name PlayerActions
extends Node
## The player's port and wreck actions: landing (S2, G4, S3), docking with a
## gate (TR5, TR6), boarding (C9) and the escape pod with rescue (C10).
## Keys: L land or dock, B board.

var scene: Node  # SystemScene
## The open landed / boarding / rescue window, if any.
var dialog: Dialog = null
## C9: the ship being boarded (tracked by instance ID: a freed ship compares
## equal to null in Godot 4) and seconds spent so far.
var boarding: Ship = null
var _boarding_id: int = 0
var _board_elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _player() -> Ship:
	return get_tree().get_first_node_in_group(&"player")


func _unhandled_input(event: InputEvent) -> void:
	if DebugCommands.console_open:
		return
	if event.is_action_pressed(&"land", false, true):
		try_land()
	elif event.is_action_pressed(&"board", false, true):
		try_board()
	else:
		return
	get_viewport().set_input_as_handled()


## S2 + G4: lands on the nearest landable object if close and slow enough and
## its government accepts the player; otherwise posts a hint. Returns "" on
## success or the reason ("none", "far", "fast", "refused").
func try_land() -> String:
	var player: Ship = _player()
	if player == null or not player.can_act() or dialog != null or scene.hyperspace.is_active():
		return "none"
	var port: SystemObjectDef = _nearest_port(player.global_position)
	if port == null:
		GameState.post_message("Nothing to land on in this system")
		return "none"
	var docking: bool = port.type == "gate"
	var landing: Dictionary = DataRegistry.settings["landing"]
	var check: String = PortRules.landing_check(player.global_position.distance_to(port.position), port.radius,
		float(landing["radius_fraction"]), player.get_velocity().length(), float(landing["max_speed"]))
	match check:
		"far":
			GameState.post_message("Too far from %s to %s" % [port.name, "dock" if docking else "land"])
			return "far"
		"fast":
			GameState.post_message("Slow down to %s %s" % ["dock with" if docking else "land on", port.name])
			return "fast"
	if docking:
		return _dock_at_gate(port, player)
	if not PortRules.landing_allowed(port.government, GameState.get_record(port.government), port.min_record):
		GameState.post_message("%s refuses you landing" % port.name)
		return "refused"
	land_at(port)
	return ""


## Puts the player down at `port` and opens the landed screen. Landing costs
## the port's landing days (TM2).
func land_at(port: SystemObjectDef, intro: String = "") -> void:
	_end_boarding()
	scene.entity_presence.on_leave()  # PS4: entities move on while you're down
	GameState.advance_days(port.landing_days)
	var player: Ship = _player()
	player.place(port.position, player.rotation)
	player.set_target(null)
	Pilots.landed_at = port.id
	dialog = LandedScreen.open(scene, port, player, func() -> void: _take_off(port), intro)
	dialog.closed.connect(func() -> void: dialog = null)
	Pilots.autosave()  # SV2, SV3: every landing


## SV1: back on the landed screen at `port` after loading a save (no days pass).
func resume_landed(port: SystemObjectDef) -> void:
	scene.entity_presence.on_leave()
	var player: Ship = _player()
	player.place(port.position, player.rotation)
	Pilots.landed_at = port.id
	dialog = LandedScreen.open(scene, port, player, func() -> void: _take_off(port))
	dialog.closed.connect(func() -> void: dialog = null)


func _take_off(port: SystemObjectDef) -> void:
	Pilots.landed_at = ""
	GameState.advance_days(port.takeoff_days)  # TM2
	scene.refresh_entities()  # PS4: who's here now
	var player: Ship = _player()
	player.place(port.position, player.rotation)
	GameState.post_message("Took off from %s" % port.name)


## The nearest place L acts on: a landable planet or station, or a gate.
func _nearest_port(from: Vector2) -> SystemObjectDef:
	var best: SystemObjectDef = null
	for obj: SystemObjectDef in scene.system.objects:
		if (obj.landable or obj.type == "gate") and (best == null or from.distance_squared_to(obj.position) < from.distance_squared_to(best.position)):
			best = obj
	return best


# --- TR5, TR6 gates -------------------------------------------------------

func _dock_at_gate(gate: SystemObjectDef, player: Ship) -> String:
	var record: float = GameState.get_record(gate.government) if gate.government != "" else 0.0
	match GateRules.dock_problem(GateRules.is_open(gate.open_condition, GameState.flags), record, gate.min_record):
		GateRules.CLOSED:
			GameState.post_message("%s is closed" % gate.name)
			return "closed"
		GateRules.RECORD:
			GameState.post_message("%s refuses you" % gate.name)
			return "refused"
	_end_boarding()
	player.place(player.global_position, player.rotation)  # docked: stopped
	player.set_target(null)
	dialog = GateScreen.open(scene, gate, scene.system.id, func(system_id: String, days: int) -> void:
		_travel_by_gate(gate, system_id, days))
	dialog.closed.connect(func() -> void: dialog = null)
	return ""


func _travel_by_gate(gate: SystemObjectDef, system_id: String, days: int) -> void:
	GameState.add_credits(-gate.fee)
	dialog.close()
	scene.leave_system()  # PS4, PS6: left now; the trip's days pass before arriving
	GameState.player_heading = system_id
	GameState.advance_days(days)
	GameState.player_heading = ""
	scene.hyperspace.arrive_at_gate(system_id)
	if bool(Pilots.pilot.get("ironman", false)):
		Pilots.autosave()  # SV3: a gate trip is a jump too
	GameState.post_message("Through %s to %s after %d day%s" % [gate.name, Hyperspace.system_name(system_id), days, "" if days == 1 else "s"])


# --- C9 boarding -----------------------------------------------------------

## Starts boarding the targeted disabled ship (or the nearest disabled one)
## if alongside and matched; returns "" or the reason ("none", "far", "fast").
func try_board() -> String:
	var player: Ship = _player()
	if player == null or not player.can_act() or dialog != null or _boarding_id != 0 or scene.hyperspace.is_active():
		return "none"
	var candidate: Ship = _board_candidate(player)
	if candidate == null:
		GameState.post_message("No disabled ship to board")
		return "none"
	var check: String = _board_check(player, candidate)
	match check:
		"far":
			GameState.post_message("Move alongside the %s to board" % candidate.def.name)
		"fast":
			GameState.post_message("Match speed with the %s to board" % candidate.def.name)
	if check != "":
		return check
	boarding = candidate
	_boarding_id = candidate.get_instance_id()
	_board_elapsed = 0.0
	if not player.health.damaged.is_connected(_on_player_hit_while_boarding):
		player.health.damaged.connect(_on_player_hit_while_boarding)
	GameState.post_message("Boarding the %s..." % candidate.def.name)
	return ""


func is_boarding() -> bool:
	return _boarding_id != 0


## 0–1 while boarding, -1 otherwise (HUD progress bar).
func board_progress() -> float:
	if _boarding_id == 0:
		return -1.0
	return clampf(_board_elapsed / float(DataRegistry.settings["boarding"]["time"]), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _boarding_id == 0:
		return
	var player: Ship = _player()
	if not is_instance_id_valid(_boarding_id) or not boarding.health.is_disabled or boarding.health.is_destroyed:
		_cancel_boarding("Boarding aborted")
		return
	if player == null or not player.can_act() or _board_check(player, boarding) != "":
		_cancel_boarding("Boarding aborted: you drifted away")
		return
	_board_elapsed += delta
	if _board_elapsed >= float(DataRegistry.settings["boarding"]["time"]):
		var ship: Ship = boarding
		_end_boarding()
		_open_boarding_window(ship)


func _on_player_hit_while_boarding(_source: Node, _amount: float) -> void:
	_cancel_boarding("Boarding aborted: you are under fire")


func _cancel_boarding(text: String) -> void:
	_end_boarding()
	GameState.post_message(text)


func _end_boarding() -> void:
	var player: Ship = _player()
	if player != null and player.health.damaged.is_connected(_on_player_hit_while_boarding):
		player.health.damaged.disconnect(_on_player_hit_while_boarding)
	boarding = null
	_boarding_id = 0


func _board_check(player: Ship, ship: Ship) -> String:
	var settings: Dictionary = DataRegistry.settings["boarding"]
	var gap: float = player.hull_gap(ship)
	var relative: float = (player.get_velocity() - ship.get_velocity()).length()
	return PortRules.boarding_check(gap, float(settings["range"]), relative, float(settings["max_speed"]))


func _board_candidate(player: Ship) -> Ship:
	var target: Ship = player.get_target()
	if target != null and target.health.is_disabled:
		return target
	var best: Ship = null
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node
		if ship == player or not ship.health.is_disabled or ship.health.is_destroyed:
			continue
		if best == null or player.global_position.distance_squared_to(ship.global_position) < player.global_position.distance_squared_to(best.global_position):
			best = ship
	return best


## C9: the paused boarding window. Choices follow PortRules.board_options.
func _open_boarding_window(ship: Ship) -> void:
	if ship.credits_aboard < 0:
		ship.credits_aboard = PortRules.board_credits(ship.def.board_credits, ship.wealth_factor(), _rng.randf())
	var gov: GovernmentDef = ship.gov_def()
	var title: String = "Boarding the %s" % ship.def.name
	var body: String = "%s, crew of %d.\n" % [gov.name if gov != null else "No government", ship.def.crew]
	body += "Credits aboard: %d." % ship.credits_aboard if not ship.looted else "You have already stripped her of credits."
	dialog = Dialog.open(scene, title, body)
	dialog.closed.connect(func() -> void: dialog = null)
	for option: String in PortRules.board_options(ship.looted, ship.player_acts.has("assist")):
		match option:
			PortRules.TAKE:
				dialog.add_choice(option, "Take %d credits" % ship.credits_aboard, func() -> void: _take(ship))
			PortRules.ASSIST:
				dialog.add_choice(option, "Assist", func() -> void: _assist(ship))
			PortRules.SCUTTLE:
				dialog.add_choice(option, "Scuttle", func() -> void: _scuttle(ship))
			PortRules.LEAVE:
				dialog.add_choice(option, "Leave", func() -> void: dialog.close())


func _take(ship: Ship) -> void:
	GameState.add_credits(ship.credits_aboard)
	GameState.report_player_act(ship, "board")
	ship.looted = true
	GameState.post_message("Took %d credits from the %s" % [ship.credits_aboard, ship.def.name], "credits")
	dialog.close()


func _assist(ship: Ship) -> void:
	ship.player_acts["assist"] = true  # once per ship: no disable/assist record farming
	ship.recover(float(DataRegistry.settings["boarding"]["assist_armor_pct"]))
	if ship.government != "":
		GameState.set_record(ship.government, Relations.after_assist(GameState.get_record(ship.government), ship.gov_def()))
	if ship.controller is AIController:
		(ship.controller as AIController).depart()
	GameState.post_message("You patch up the %s; she limps away" % ship.def.name)
	dialog.close()


func _scuttle(ship: Ship) -> void:
	var player: Ship = _player()
	dialog.close()
	ship.scuttle_by(player)
	GameState.post_message("The %s is scuttled" % ship.def.name, "combat")


# --- C10 escape pod and rescue ----------------------------------------------

## Connected to the player's ship_destroyed signal by the system scene.
func on_player_destroyed(player: Ship) -> void:
	_end_boarding()
	if dialog != null:
		dialog.close()
	if not bool(Pilots.pilot.get("escape_pod", DataRegistry.settings["player"]["escape_pod"])):  # SV1: the pilot's pod
		_lost_with_all_hands()
		return
	var pod := EscapePod.launch(scene.world, player.global_position, FlightModel.heading(player.global_rotation), player.get_velocity())
	scene.camera.target = pod
	pod.finished.connect(_rescue)
	GameState.post_message("Escape pod away!")


func _rescue(pod: EscapePod) -> void:
	var settings: Dictionary = DataRegistry.settings["player"]
	var player: Ship = _player()
	var from: Vector2 = pod.global_position
	pod.queue_free()
	var fee: int = PortRules.rescue_fee(GameState.credits, float(settings["rescue_fee_pct"]))
	GameState.add_credits(-fee)
	var days: Array = settings["rescue_days"]
	var days_passed: int = _rng.randi_range(roundi(days[0]), roundi(days[1]))
	scene.leave_system()  # PS4, PS6: wrecks age and entities move while the pod drifts
	GameState.advance_days(days_passed)  # TM2: the days adrift pass on the calendar
	var objects: Array[SystemObjectDef] = scene.system.objects
	var index: int = PortRules.rescue_port(objects, from, GameState.records(), float(settings["record"]))
	var port: SystemObjectDef = objects[index] if index >= 0 else null
	# Days pass: like leaving and coming back. Every other ship goes, destroyed
	# scenery returns and traffic refills; remembered wrecks still in date stay (PS6).
	scene.reset_visit()
	# Insured: like for like. Uninsured: a basic hull.
	var insured: bool = bool(Pilots.pilot.get("insured", settings["insured"]))  # SV1: the pilot's insurance
	var hull: ShipDef = player.def if insured else DataRegistry.get_ship(settings["uninsured_ship"])
	player.setup(hull)
	player.place(port.position if port != null else Vector2.ZERO, 0.0)
	scene.camera.target = player
	var gov: GovernmentDef = DataRegistry.get_government(port.government) if port != null and port.government != "" else null
	var rescuer: String = "a %s ship" % gov.name if gov != null else "a passing freighter"
	var where: String = port.name if port != null else "the middle of the system"
	var text: String = "Your ship was destroyed. Your escape pod drifted for %d days before you were picked up by %s and brought to %s.\n\nRescue fee: %d credits." % [days_passed, rescuer, where, fee]
	text += "\n\nYour insurer has replaced your %s." % hull.name if insured else "\n\nYou weren't insured. All you could get was a %s." % hull.name
	dialog = Dialog.open(scene, "Rescued", text)
	dialog.add_choice("continue", "Continue", func() -> void:
		dialog.close()
		if port != null:
			land_at.call_deferred(port))
	dialog.closed.connect(func() -> void: dialog = null)


func _lost_with_all_hands() -> void:
	var text: String = "Your ship was destroyed and there was no escape pod aboard."
	if bool(Pilots.pilot.get("ironman", false)):
		Pilots.mark_dead()  # SV3: an ironman pilot's story ends here
		text += "\n\n%s's record is kept in the pilot list." % Pilots.pilot.get("name", "Your pilot")
	dialog = Dialog.open(scene, "Lost with all hands", text)
	if Pilots.has_pilot():
		if not bool(Pilots.pilot.get("ironman", false)) and not Pilots.list_slots(Pilots.pilot_id).is_empty():
			dialog.add_choice("load", "Load latest save", func() -> void:
				dialog.close()
				Pilots.load_save(Pilots.pilot_id, Pilots.list_slots(Pilots.pilot_id)[0]["id"]))
		dialog.add_choice("menu", "Main menu", func() -> void:
			dialog.close()
			Pilots.quit_to_menu(false))
	else:
		dialog.add_choice("restart", "Restart", func() -> void:
			dialog.close()
			GameState.reset()
			DebugCommands.reset_session()
			get_tree().paused = false
			get_tree().reload_current_scene())
	dialog.closed.connect(func() -> void: dialog = null)
