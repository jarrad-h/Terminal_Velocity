class_name PlayerActions
extends Node
## The player's port and wreck actions: landing (S2, G4, S3), boarding (C9)
## and the escape pod with rescue (C10). Keys: L land, B board.

var scene: Node  # SystemScene
## The open landed / boarding / rescue window, if any.
var dialog: Dialog = null
## C9: the ship being boarded and seconds spent so far.
var boarding: Ship = null
var _board_elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _player() -> Ship:
	return get_tree().get_first_node_in_group(&"player")


func _unhandled_input(event: InputEvent) -> void:
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
	if player == null or not player.can_act() or dialog != null:
		return "none"
	var port: SystemObjectDef = _nearest_landable(player.global_position)
	if port == null:
		GameState.post_message("Nothing to land on in this system")
		return "none"
	var landing: Dictionary = DataRegistry.settings["landing"]
	var check: String = PortRules.landing_check(player.global_position.distance_to(port.position), port.radius,
		float(landing["radius_fraction"]), player.get_velocity().length(), float(landing["max_speed"]))
	match check:
		"far":
			GameState.post_message("Too far from %s to land" % port.name)
			return "far"
		"fast":
			GameState.post_message("Slow down to land on %s" % port.name)
			return "fast"
	if not PortRules.landing_allowed(port.government, GameState.get_record(port.government), port.min_record):
		GameState.post_message("%s refuses you landing" % port.name)
		return "refused"
	land_at(port)
	return ""


## Puts the player down at `port` and opens the landed screen.
func land_at(port: SystemObjectDef, intro: String = "") -> void:
	var player: Ship = _player()
	player.place(port.position, player.rotation)
	player.set_target(null)
	dialog = LandedScreen.open(scene, port, player, func() -> void: _take_off(port), intro)
	dialog.closed.connect(func() -> void: dialog = null)


func _take_off(port: SystemObjectDef) -> void:
	var player: Ship = _player()
	player.place(port.position, player.rotation)
	GameState.post_message("Took off from %s" % port.name)


func _nearest_landable(from: Vector2) -> SystemObjectDef:
	var best: SystemObjectDef = null
	for obj: SystemObjectDef in scene.system.objects:
		if obj.landable and (best == null or from.distance_squared_to(obj.position) < from.distance_squared_to(best.position)):
			best = obj
	return best


# --- C9 boarding -----------------------------------------------------------

## Starts boarding the targeted disabled ship (or the nearest disabled one)
## if alongside and matched; returns "" or the reason ("none", "far", "fast").
func try_board() -> String:
	var player: Ship = _player()
	if player == null or not player.can_act() or dialog != null or boarding != null:
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
	_board_elapsed = 0.0
	player.health.damaged.connect(_on_player_hit_while_boarding)
	GameState.post_message("Boarding the %s..." % candidate.def.name)
	return ""


## 0–1 while boarding, -1 otherwise (HUD progress bar).
func board_progress() -> float:
	if boarding == null:
		return -1.0
	return clampf(_board_elapsed / float(DataRegistry.settings["boarding"]["time"]), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if boarding == null:
		return
	var player: Ship = _player()
	if not is_instance_valid(boarding) or not boarding.health.is_disabled or boarding.health.is_destroyed:
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


func _board_check(player: Ship, ship: Ship) -> String:
	var settings: Dictionary = DataRegistry.settings["boarding"]
	var gap: float = player.global_position.distance_to(ship.global_position) - player.hit_radius - ship.hit_radius
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
	for option: String in PortRules.board_options(ship.looted):
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
	GameState.post_message("Took %d credits from the %s" % [ship.credits_aboard, ship.def.name])
	dialog.close()


func _assist(ship: Ship) -> void:
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
	GameState.post_message("The %s is scuttled" % ship.def.name)


# --- C10 escape pod and rescue ----------------------------------------------

## Connected to the player's ship_destroyed signal by the system scene.
func on_player_destroyed(player: Ship) -> void:
	_end_boarding()
	if dialog != null:
		dialog.close()
	if not bool(DataRegistry.settings["player"]["escape_pod"]):
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
	var objects: Array[SystemObjectDef] = scene.system.objects
	var index: int = PortRules.rescue_port(objects, from, GameState.records(), float(settings["record"]))
	var port: SystemObjectDef = objects[index] if index >= 0 else null
	# Days pass: like leaving and coming back (every other ship, wrecks
	# included, destroyed scenery, then fresh traffic).
	scene.reset_visit()
	# Insured: like for like. Uninsured: a basic hull.
	var insured: bool = bool(settings["insured"])
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
	dialog = Dialog.open(scene, "Lost with all hands", "Your ship was destroyed and there was no escape pod aboard.")
	dialog.add_choice("restart", "Restart", func() -> void:
		dialog.close()
		GameState.reset()
		get_tree().paused = false
		get_tree().reload_current_scene())
	dialog.closed.connect(func() -> void: dialog = null)
