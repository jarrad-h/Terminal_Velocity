extends Node2D
## Root of the star system: starfield, camera, the player ship and the
## current system definition.

const SHIP_SCENE: PackedScene = preload("res://scenes/ship.tscn")
const DEBUG_PANEL_SCENE: String = "res://scenes/debug_panel.tscn"

var system: SystemDef = null

@onready var starfield: Starfield = $Starfield
@onready var world: Node2D = $World
@onready var camera: FollowCamera = $Camera


func _ready() -> void:
	add_to_group(&"system_scene")
	if not DataRegistry.load_errors.is_empty():
		var screen := DataErrorScreen.new()
		add_child(screen)
		screen.show_errors(DataRegistry.load_errors)
		return
	var settings: Dictionary = DataRegistry.settings
	RenderingServer.set_default_clear_color(Color.html(settings["background_colour"]))
	starfield.configure(settings["starfield"])
	camera.configure(settings["camera"])
	load_system(settings["system"])

	var player: Ship = spawn_ship(settings["player_ship"], Vector2.ZERO)
	if player != null:
		player.add_to_group(&"player")
		player.set_controller(PlayerController.new())
		camera.target = player

	DataRegistry.data_reloaded.connect(_on_data_reloaded)
	if OS.is_debug_build():
		var overlay := DebugOverlay.new()
		world.add_child(overlay)
		add_child(load(DEBUG_PANEL_SCENE).instantiate())


## Switches the backdrop and local space to another system definition.
func load_system(system_id: String) -> bool:
	var next: SystemDef = DataRegistry.get_system(system_id)
	if next == null:
		push_error("No system with id '%s'" % system_id)
		return false
	system = next
	return true


func spawn_ship(ship_id: String, at: Vector2) -> Ship:
	var def: ShipDef = DataRegistry.get_ship(ship_id)
	if def == null:
		push_error("No ship with id '%s'" % ship_id)
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.position = at
	world.add_child(ship)
	ship.setup(def)
	return ship


func _on_data_reloaded() -> void:
	camera.configure(DataRegistry.settings["camera"])
	if not load_system(system.id):
		load_system(DataRegistry.settings["system"])
