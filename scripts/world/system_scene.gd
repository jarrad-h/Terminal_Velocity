extends Node2D
## Root of the star system: backdrop, local-space scenery, camera and the
## player ship, all driven by the current system definition.

const SHIP_SCENE: PackedScene = preload("res://scenes/ship.tscn")
const DEBUG_PANEL_SCENE: String = "res://scenes/debug_panel.tscn"

var system: SystemDef = null

@onready var backdrop: Backdrop = $Backdrop
@onready var local_space: LocalSpace = $World/LocalSpace
@onready var system_objects: SystemObjects = $World/SystemObjects
@onready var world: Node2D = $World
@onready var ships: Node2D = $World/Ships
@onready var hud: Hud = $Hud
@onready var camera: FollowCamera = $Camera
@onready var traffic: TrafficSpawner = $TrafficSpawner
var actions: PlayerActions
var hyperspace: Hyperspace
var lighting: SystemLighting


func _ready() -> void:
	add_to_group(&"system_scene")
	$World/Shots.add_to_group(&"shots")
	if not DataRegistry.load_errors.is_empty():
		var screen := DataErrorScreen.new()
		add_child(screen)
		screen.show_errors(DataRegistry.load_errors)
		return
	var settings: Dictionary = DataRegistry.settings
	actions = PlayerActions.new()
	actions.name = "PlayerActions"
	actions.scene = self
	add_child(actions)
	hyperspace = Hyperspace.new()
	hyperspace.name = "Hyperspace"
	hyperspace.scene = self
	add_child(hyperspace)
	camera.configure(settings["camera"])
	lighting = SystemLighting.new()
	lighting.name = "Lighting"
	world.add_child(lighting)
	world.move_child(lighting, 0)
	lighting.enabled = bool(settings["lighting"]["enabled"])
	load_system(GameState.travel.current_system)

	var player: Ship = spawn_ship(settings["player_ship"], Vector2.ZERO)
	if player != null:
		player.add_to_group(&"player")
		player.setup(player.def)  # recolour now it is the player
		player.set_controller(PlayerController.new())
		player.ship_destroyed.connect(actions.on_player_destroyed)
		camera.target = player
	hud.player = player
	hud.actions = actions
	hud.hyperspace = hyperspace

	DataRegistry.data_reloaded.connect(_on_data_reloaded)
	if OS.is_debug_build():
		var overlay := DebugOverlay.new()
		world.add_child(overlay)
		add_child(load(DEBUG_PANEL_SCENE).instantiate())
		var console := DebugConsole.new()
		console.name = "DebugConsole"
		add_child(console)
		for spawn: Dictionary in settings["debug"]["spawn_at_start"]:
			var at: Array = spawn.get("position", [0, 0])
			var ship: Ship = spawn_ship(spawn["ship"], Vector2(at[0], at[1]), spawn.get("government", ""))
			if ship != null:
				ship.set_controller(IdleController.new())


## Switches the backdrop and local space to another system definition.
func load_system(system_id: String) -> bool:
	var next: SystemDef = DataRegistry.get_system(system_id)
	if next == null:
		push_error("No system with id '%s'" % system_id)
		return false
	var new_system: bool = system == null or system.id != next.id
	system = next
	backdrop.configure(system.backdrop)
	system_objects.configure(system)
	lighting.configure(system)
	local_space.configure(system, float(DataRegistry.settings["local_space"]["chunk_size"]))
	traffic.configure(system, new_system)
	return true


## C10: as if the player left and came back — every other ship goes,
## destroyed scenery returns, and traffic refills.
func reset_visit() -> void:
	_record_wrecks()
	_clear_ships_and_shots()
	local_space.reset_visit()
	traffic.configure(system, true)
	_restore_wrecks()


## TR2, TR4: the player leaves this system for `system_id`, arriving at its
## jump radius moving along `bearing` (origin → destination on the map).
## Each arrival is a fresh visit until persistence (milestone 3).
func enter_system(system_id: String, bearing: Vector2) -> void:
	var next: SystemDef = DataRegistry.get_system(system_id)
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	var arrival: FlightState = null
	if player != null and next != null:
		var settings: Dictionary = DataRegistry.settings["hyperspace"]
		var speed: float = player.def.top_speed * float(settings["arrival_speed_fraction"])
		arrival = Hyperlanes.arrival(bearing, next.jump_radius, speed, float(settings["arrival_grace_seconds"]))
	_enter(system_id, arrival)


## TR5: arrives stopped at `at` (a gate's jump point), keeping the heading.
func enter_system_at(system_id: String, at: Vector2) -> void:
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	_enter(system_id, FlightState.new(at, Vector2.ZERO, player.rotation if player != null else 0.0))


func _enter(system_id: String, arrival: FlightState) -> void:
	_record_wrecks()
	_clear_ships_and_shots()
	var same_system: bool = system != null and system.id == system_id
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	if player != null and arrival != null:
		player.place(arrival.position, arrival.rotation, arrival.velocity)
		player.set_target(null)
	load_system(system_id)
	local_space.reset_visit()
	if same_system:
		traffic.configure(system, true)  # D11 goto here: refill like a fresh visit
	_restore_wrecks()
	if player != null:
		Flash.spawn(world, player.global_position, player.hit_radius * 2.0, Color(0.6, 0.8, 1.0), 0.5)


## PS6: disabled ships the player leaves behind are remembered for
## memory.wreck_days days (from when each was first left). Call before days
## pass on leaving, so each wreck's clock starts when it was left.
func record_wrecks() -> void:
	_record_wrecks()


func _record_wrecks() -> void:
	if system == null:
		return
	var today: int = GameState.clock.day
	var wreck_days: int = int(DataRegistry.settings["memory"]["wreck_days"])
	var list: Array = []
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node
		if ship.is_player() or not ship.health.is_disabled or ship.health.is_destroyed or ship.docked:
			continue
		var expires: int = int(ship.get_meta("wreck_expires", today + wreck_days))
		ship.set_meta("wreck_expires", expires)
		if expires <= today:
			continue
		var ai: AIController = ship.controller as AIController
		list.append({"ship": ship.def.id, "government": ship.government,
			"pool": ai.pool.id if ai != null else "", "personality": ai.personality.id if ai != null else "",
			"armor_pct": ship.health.armor / maxf(ship.health.max_armor, 0.001),
			"position": [ship.global_position.x, ship.global_position.y], "rotation": ship.global_rotation,
			"credits": ship.credits_aboard, "looted": ship.looted, "acts": ship.player_acts.keys(),
			"days_left": expires - today})
	GameState.memory.set_wrecks(system.id, list)


## PS6: the system's remembered wrecks are back where they were, still
## disabled, with their AI (so Assist sends them on their way, C9).
func _restore_wrecks() -> void:
	if system == null:
		return
	var today: int = GameState.clock.day
	for wreck: Dictionary in GameState.memory.wrecks_in(system.id):
		var at := Vector2(wreck["position"][0], wreck["position"][1])
		var ship: Ship = spawn_ship(wreck["ship"], at, wreck["government"])
		if ship == null:
			continue
		ship.set_meta("wreck_expires", today + int(wreck["days_left"]))
		ship.place(at, float(wreck["rotation"]))
		var pool: AiPoolDef = DataRegistry.get_ai_pool(str(wreck.get("pool", "")))
		if pool != null:
			var personality: PersonalityDef = DataRegistry.get_personality(str(wreck.get("personality", "")))
			var ai := AIController.new()
			ai.setup(pool, personality if personality != null else PersonalityDef.neutral(), system, "inside")
			ship.set_controller(ai)
		else:
			ship.set_controller(IdleController.new())
		ship.credits_aboard = int(wreck["credits"])
		ship.looted = bool(wreck["looted"])
		for act: Variant in wreck["acts"]:
			ship.player_acts[str(act)] = true
		ship.set_meta("restoring", true)  # not a new loss (PS6)
		ship.health.force_disable()
		ship.health.armor = minf(ship.health.armor, ship.health.max_armor * float(wreck.get("armor_pct", 1.0)))
		ship.remove_meta("restoring")
	GameState.memory.set_wrecks(system.id, [])


func _clear_ships_and_shots() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		if not node.is_in_group(&"player"):
			node.remove_from_group(&"ships")
			node.queue_free()
	for shot: Node in $World/Shots.get_children():
		shot.queue_free()


## Spawns a ship. Non-player ships get an IdleController until M4 adds AI.
func spawn_ship(ship_id: String, at: Vector2, government: String = "") -> Ship:
	var def: ShipDef = DataRegistry.get_ship(ship_id)
	if def == null:
		push_error("No ship with id '%s'" % ship_id)
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.position = at
	ship.government = government
	ships.add_child(ship)
	ship.setup(def)
	return ship


func _on_data_reloaded() -> void:
	camera.configure(DataRegistry.settings["camera"])
	if not load_system(system.id):
		load_system(DataRegistry.galaxy().start_system)
