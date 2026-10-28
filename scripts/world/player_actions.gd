class_name PlayerActions
extends Node
## The player's port and wreck actions: landing (S2, G4, S3), and later
## boarding (C9) and the escape pod (C10). Keys: L land, B board.

var scene: Node  # SystemScene
## The open landed / boarding / rescue window, if any.
var dialog: Dialog = null


func _player() -> Ship:
	return get_tree().get_first_node_in_group(&"player")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"land", false, true):
		try_land()
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
