extends Node2D
## Root of the star system. Milestone 1: starfield, camera and the player ship.

const SHIP_SCENE: PackedScene = preload("res://scenes/ship.tscn")
const DEBUG_PANEL_SCENE: String = "res://scenes/debug_panel.tscn"

@onready var starfield: Starfield = $Starfield
@onready var world: Node2D = $World
@onready var camera: FollowCamera = $Camera


func _ready() -> void:
	var settings: Dictionary = DataRegistry.settings
	RenderingServer.set_default_clear_color(Color.html(settings["background_colour"]))
	starfield.configure(settings["starfield"])
	camera.configure(settings["camera"])

	var player: Ship = spawn_ship(settings["player_ship"], Vector2.ZERO)
	if player != null:
		player.add_to_group(&"player")
		player.set_controller(PlayerController.new())
		camera.target = player

	if OS.is_debug_build():
		var overlay := DebugOverlay.new()
		world.add_child(overlay)
		add_child(load(DEBUG_PANEL_SCENE).instantiate())


func spawn_ship(ship_id: String, at: Vector2) -> Ship:
	var def: Dictionary = DataRegistry.get_ship(ship_id)
	if def.is_empty():
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.position = at
	world.add_child(ship)
	ship.setup(def)
	return ship
