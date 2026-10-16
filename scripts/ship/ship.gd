class_name Ship
extends Node2D
## One scene for player and AI ships. The controller child decides behaviour;
## ShipBody flies, Health takes damage (C5–C7).

signal ship_destroyed(ship: Ship)
signal target_changed(target: Ship)

const SPRITE_DIR: String = "res://assets/sprites"
const DISABLED_TINT := Color(0.45, 0.45, 0.5)

var def: ShipDef = null
var hit_radius: float = 0.0
var controller: Node = null
## Government ID ("" = none). Set at spawn; drives radar colour until M4.
var government: String = ""
var _target: Ship = null

@onready var body: ShipBody = $ShipBody
@onready var visual: Node2D = $Visual
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health: Health = $Health


func _ready() -> void:
	add_to_group(&"ships")
	DataRegistry.data_reloaded.connect(_on_data_reloaded)
	health.disabled.connect(_on_disabled)
	health.destroyed.connect(_on_destroyed)


## Applies a ship definition. Call after adding to the tree. Calling it again
## (ship swap, hot reload) keeps position, velocity and heading, and restores
## full shield and armour.
func setup(ship_def: ShipDef) -> void:
	def = ship_def
	hit_radius = def.hit_radius
	body.stats = FlightStats.from_ship_def(def)
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	hitbox_shape.shape = circle
	health.setup(def.shield, def.armor, def.shield_regen, def.disable_armor_pct / 100.0)
	visible = true
	visual.modulate = Color.WHITE
	body.set_physics_process(true)
	_build_visual()


func set_controller(new_controller: Node) -> void:
	if controller != null:
		controller.queue_free()
	controller = new_controller
	controller.name = "Controller"
	add_child(controller)


## Controller intent for this frame; nothing while disabled (C7: drifts).
func get_flight_input() -> FlightInput:
	if controller == null or not can_act():
		return FlightInput.new()
	return controller.get_flight_input()


func can_act() -> bool:
	return not health.is_disabled and not health.is_destroyed


func is_player() -> bool:
	return is_in_group(&"player")


## Short label for the AI-state debug overlay.
func get_state_label() -> String:
	var label: String = "no controller" if controller == null else controller.get_state_label()
	if health.is_disabled:
		label += " (disabled)"
	return label


func get_velocity() -> Vector2:
	return body.state.velocity


## C8: the selected target, or null once it is gone.
func get_target() -> Ship:
	if _target != null and (not is_instance_valid(_target) or _target.health.is_destroyed):
		_target = null
		target_changed.emit(null)
	return _target


func set_target(ship: Ship) -> void:
	if ship == _target:
		return
	_target = ship
	target_changed.emit(ship)


func target_nearest() -> void:
	var candidates: Array[Ship] = _target_candidates()
	var index: int = Targeting.nearest(global_position, _positions(candidates))
	set_target(candidates[index] if index >= 0 else null)


func cycle_target() -> void:
	var candidates: Array[Ship] = _target_candidates()
	var index: int = Targeting.cycle(global_position, _positions(candidates), candidates.find(get_target()))
	set_target(candidates[index] if index >= 0 else null)


func _target_candidates() -> Array[Ship]:
	var result: Array[Ship] = []
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node
		if ship != self and not ship.health.is_destroyed:
			result.append(ship)
	return result


func _positions(ships: Array[Ship]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for ship: Ship in ships:
		result.append(ship.global_position)
	return result


func _on_disabled() -> void:
	visual.modulate = DISABLED_TINT


func _on_destroyed() -> void:
	Flash.spawn(get_parent(), global_position, hit_radius * 2.5, Color(1.0, 0.7, 0.3), 0.8)
	ship_destroyed.emit(self)
	if is_player():
		# Respawn (C10) arrives in milestone 5; until then the wreck just vanishes.
		visible = false
		body.set_physics_process(false)
		return
	queue_free()


func _on_data_reloaded() -> void:
	var fresh: ShipDef = DataRegistry.get_ship(def.id)
	if fresh != null:
		setup(fresh)


func _build_visual() -> void:
	for child: Node in visual.get_children():
		child.queue_free()
	var sprite_path: String = SPRITE_DIR.path_join(def.sprite)
	if def.sprite != "" and ResourceLoader.exists(sprite_path):
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
