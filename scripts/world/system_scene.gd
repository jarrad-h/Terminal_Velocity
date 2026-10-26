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


func _ready() -> void:
	add_to_group(&"system_scene")
	$World/Shots.add_to_group(&"shots")
	if not DataRegistry.load_errors.is_empty():
		var screen := DataErrorScreen.new()
		add_child(screen)
		screen.show_errors(DataRegistry.load_errors)
		return
	var settings: Dictionary = DataRegistry.settings
	camera.configure(settings["camera"])
	load_system(settings["system"])

	var player: Ship = spawn_ship(settings["player_ship"], Vector2.ZERO)
	if player != null:
		player.add_to_group(&"player")
		player.setup(player.def)  # recolour now it is the player
		player.set_controller(PlayerController.new())
		camera.target = player
	hud.player = player

	DataRegistry.data_reloaded.connect(_on_data_reloaded)
	if OS.is_debug_build():
		var overlay := DebugOverlay.new()
		world.add_child(overlay)
		add_child(load(DEBUG_PANEL_SCENE).instantiate())
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
	if system != null and new_system:
		GameState.clear_system_state()
	system = next
	backdrop.configure(system.backdrop)
	system_objects.configure(system)
	local_space.configure(system, float(DataRegistry.settings["local_space"]["chunk_size"]))
	traffic.configure(system, new_system)
	return true


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
		load_system(DataRegistry.settings["system"])
