class_name Ship
extends Node2D
## One scene for player and AI ships. The controller child decides behaviour.

const SPRITE_DIR: String = "res://assets/sprites"

var def: Dictionary = {}
var hit_radius: float = 0.0
var controller: Node = null

@onready var body: ShipBody = $ShipBody
@onready var visual: Node2D = $Visual
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	add_to_group(&"ships")


## Applies a ship definition from DataRegistry. Call after adding to the tree.
func setup(ship_def: Dictionary) -> void:
	def = ship_def
	hit_radius = float(def["hit_radius"])
	body.stats = FlightStats.from_ship_def(def)
	body.state.position = position
	body.state.rotation = rotation
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	hitbox_shape.shape = circle
	_build_visual()


func set_controller(new_controller: Node) -> void:
	if controller != null:
		controller.queue_free()
	controller = new_controller
	controller.name = "Controller"
	add_child(controller)


func get_flight_input() -> FlightInput:
	if controller == null:
		return FlightInput.new()
	return controller.get_flight_input()


## Short label for the AI-state debug overlay.
func get_state_label() -> String:
	if controller == null:
		return "no controller"
	return controller.get_state_label()


func get_velocity() -> Vector2:
	return body.state.velocity


func _build_visual() -> void:
	for child: Node in visual.get_children():
		child.queue_free()
	var sprite_path: String = "%s/%s" % [SPRITE_DIR, def["sprite"]]
	if def["sprite"] != "" and ResourceLoader.exists(sprite_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(sprite_path)
		visual.add_child(sprite)
		return
	# Placeholder art: an arrowhead pointing along the heading (up).
	var r: float = hit_radius
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2(0.0, -r), Vector2(r * 0.7, r * 0.8), Vector2(0.0, r * 0.4), Vector2(-r * 0.7, r * 0.8),
	])
	shape.color = Color(0.75, 0.85, 1.0)
	visual.add_child(shape)
