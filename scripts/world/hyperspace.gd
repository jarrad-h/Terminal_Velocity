class_name Hyperspace
extends Node
## The player's hyperlane jump (TR2–TR4, TR8, TM2) and the galaxy map (TR7,
## M). J checks the jump and
## hands the ship to a JumpSequence (controls locked); J again or firing
## cancels until the countdown ends (then the ship is committed), and being
## disabled cancels at any point. When the hyperdrive engages, fuel and
## days are spent and the next system loads with the player at its jump radius.

var scene: Node  # SystemScene
var sequence: JumpSequence = null
## TR7: the open galaxy map, if any.
var map: GalaxyMap = null
var _destination: String = ""


func _player() -> Ship:
	return get_tree().get_first_node_in_group(&"player")


func is_active() -> bool:
	return sequence != null


## HUD line: the phase while jumping, else "".
func status_text() -> String:
	return sequence.label() if sequence != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if DebugCommands.console_open:
		return
	if event.is_action_pressed(&"galaxy_map", false, true):
		open_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"jump", false, true):
		if is_active():
			cancel("Jump cancelled")
		else:
			try_jump()
		get_viewport().set_input_as_handled()
	elif is_active() and (event.is_action_pressed(&"fire_primary") or event.is_action_pressed(&"fire_secondary")):
		cancel("Jump cancelled: weapons fired")


## TR7: opens the galaxy map (not while landed, boarding or in another window).
func open_map() -> GalaxyMap:
	if map != null or scene.actions.dialog != null or _player() == null:
		return null
	if is_active():
		GameState.post_message("The map is locked while the hyperdrive is engaged")
		return null
	map = GalaxyMap.open(scene, self)
	map.closed.connect(func() -> void: map = null)
	return map


## TR2: starts the jump to the plotted destination, or posts why it can't.
## Returns "" on success, else a Hyperlanes problem or "none".
func try_jump() -> String:
	var player: Ship = _player()
	if player == null or not player.can_act() or is_active() or scene.actions.dialog != null or scene.actions.is_boarding():
		return "none"
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var travel: TravelState = GameState.travel
	var destination: String = travel.destination()
	var adjacent: bool = destination != "" and Hyperlanes.are_adjacent(galaxy, travel.current_system, destination, travel.hidden_set(galaxy))
	var needed: float = jump_fuel_to(destination) if adjacent else 0.0
	var problem: String = Hyperlanes.jump_problem(destination, adjacent, player.global_position.length(),
		scene.system.jump_radius, travel.fuel, needed)
	match problem:
		Hyperlanes.NO_DESTINATION:
			GameState.post_message("No destination: open the map (M) and pick a system")
		Hyperlanes.NOT_ADJACENT:
			GameState.post_message("%s is not one hyperlane away" % system_name(destination))
		Hyperlanes.INSIDE:
			GameState.post_message("Too deep in the system to jump: fly beyond %.0f from the centre" % scene.system.jump_radius)
		Hyperlanes.NO_FUEL:
			GameState.post_message("Not enough fuel to jump (need %.0f, have %.0f)" % [needed, travel.fuel])
	if problem != "":
		return problem
	_destination = destination
	sequence = JumpSequence.new(Hyperlanes.bearing(galaxy, travel.current_system, destination),
		player.def.jump_countdown, DataRegistry.settings["hyperspace"], player.body.stats)
	player.autopilot = sequence
	GameState.post_message("Preparing to jump to %s" % system_name(destination))
	return ""


## TR2: a voluntary cancel (J, firing, debug goto). Once the countdown has
## ended the jump is committed and this does nothing.
func cancel(text: String) -> void:
	if sequence == null:
		return
	if not sequence.cancel():
		GameState.post_message("Hyperdrive committed: can't cancel now")
		return
	_stop(text)


## Being disabled stops the jump even when committed.
func abort(text: String) -> void:
	if sequence == null:
		return
	sequence.abort()
	_stop(text)


func _stop(text: String) -> void:
	sequence = null
	var player: Ship = _player()
	if player != null:
		player.autopilot = null
	GameState.post_message(text)


func _physics_process(_delta: float) -> void:
	if sequence == null:
		return
	var player: Ship = _player()
	if player == null or not player.can_act():
		abort("Jump cancelled: ship disabled")
	elif sequence.is_engaged():
		_complete(player)


## TR8, TM2, TR4: spend fuel and days, then arrive.
func _complete(player: Ship) -> void:
	var travel: TravelState = GameState.travel
	var origin: String = travel.current_system
	var length: float = Hyperlanes.lane_length(DataRegistry.galaxy(), origin, _destination)
	var days: int = Hyperlanes.jump_days(length, player.def.jump_speed)
	sequence = null
	player.autopilot = null
	GameState.set_fuel(travel.fuel - Hyperlanes.jump_fuel(player.def.jump_fuel, length), player.def.fuel)
	if not travel.route.is_empty() and travel.route[0] == _destination:
		travel.route.pop_front()
	arrive(_destination, origin)
	GameState.advance_days(days)
	var text: String = "Arrived in %s after %d day%s" % [system_name(_destination), days, "" if days == 1 else "s"]
	if not travel.route.is_empty():
		text += "; next jump %s" % system_name(travel.route[0])
	GameState.post_message(text)


## TR4: puts the player in `system_id`, arriving from `origin` (any system on
## the map; "" arrives from the north). Also used by debug goto (D11).
func arrive(system_id: String, origin: String) -> void:
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var travel: TravelState = GameState.travel
	var bearing: Vector2 = Vector2.DOWN
	if origin != "" and galaxy.has_system(origin) and origin != system_id:
		bearing = Hyperlanes.bearing(galaxy, origin, system_id)
	travel.current_system = system_id
	travel.mark_explored(system_id)
	scene.enter_system(system_id, bearing)


## TR7: plots the fewest-days route to `system_id` for the player's ship;
## returns false (route unchanged) if it's unreachable or hidden. Plotting
## where you are clears the route.
func plot_to(system_id: String) -> bool:
	var player: Ship = _player()
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var travel: TravelState = GameState.travel
	if player == null or is_active():
		return false
	if system_id == travel.current_system:
		travel.route.clear()
		return true
	var route: Array[String] = Hyperlanes.plot_route(galaxy, travel.current_system, system_id, player.def.jump_speed, travel.hidden_set(galaxy))
	if route.is_empty():
		return false
	travel.route = route
	return true


## TR5: arrives through `system_id`'s gate (stopped at its jump point). A
## plotted route is replotted from here to its end, or cleared.
func arrive_at_gate(system_id: String) -> void:
	var travel: TravelState = GameState.travel
	var goal: String = travel.route[-1] if not travel.route.is_empty() else ""
	travel.current_system = system_id
	travel.mark_explored(system_id)
	travel.route.clear()
	var gate: SystemObjectDef = DataRegistry.get_system(system_id).gate()
	scene.enter_system_at(system_id, gate.position + StellarArt.jump_point(gate))
	if goal != "" and goal != system_id:
		plot_to(goal)


## Display name of a system, or its id if it has no definition.
static func system_name(system_id: String) -> String:
	var def: SystemDef = DataRegistry.get_system(system_id)
	return def.name if def != null else system_id


## TR8: fuel the player's ship needs to jump to `destination` from here.
func jump_fuel_to(destination: String) -> float:
	var player: Ship = _player()
	if player == null or destination == "":
		return 0.0
	return Hyperlanes.jump_fuel(player.def.jump_fuel,
		Hyperlanes.lane_length(DataRegistry.galaxy(), GameState.travel.current_system, destination))
