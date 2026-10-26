class_name Ship
extends Node2D
## One scene for player and AI ships. The controller child decides behaviour;
## ShipBody flies, Health takes damage (C5–C7).

signal ship_destroyed(ship: Ship)
signal target_changed(target: Ship)
## Damaged by another ship (after hostility bookkeeping).
signal attacked(attacker: Ship)

const SPRITE_DIR: String = "res://assets/sprites"
const DISABLED_TINT := Color(0.45, 0.45, 0.5)

var def: ShipDef = null
var hit_radius: float = 0.0
var controller: Node = null
## Government ID ("" = none). Set at spawn.
var government: String = ""
## AI role from its pool ("trader", "warship", "pirate"); "" for the player and idle ships.
var role: String = ""
## A1: a docked trader is hidden, untargetable and ignored by AI.
var docked: bool = false
## G2: acts the player has already been charged for against this ship.
var player_acts: Dictionary = {}
## A8: ships that have damaged this one (non-allied); treated as hostile.
var _aggressors: Dictionary = {}
var _last_attacker: Ship = null
var _target: Ship = null

@onready var body: ShipBody = $ShipBody
@onready var visual: Node2D = $Visual
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health: Health = $Health
@onready var weapons: WeaponMounts = $WeaponMounts


func _ready() -> void:
	add_to_group(&"ships")
	DataRegistry.data_reloaded.connect(_on_data_reloaded)
	health.disabled.connect(_on_disabled)
	health.destroyed.connect(_on_destroyed)
	health.damaged.connect(_on_damaged)


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
	hitbox_shape.set_deferred(&"disabled", false)
	weapons.setup(def)
	visible = true
	visual.modulate = Color.WHITE
	body.set_physics_process(true)
	_build_visual()
	if docked:
		set_docked(true)  # a docked trader stays docked through swap/reload


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
	if _target != null and (not is_instance_valid(_target) or not _target.is_active()):
		_target = null
		target_changed.emit(null)
	return _target


func set_target(ship: Ship) -> void:
	if ship == _target:
		return
	_target = ship
	target_changed.emit(ship)


## C8: nearest hostile ship, or the nearest ship if none are hostile.
func target_nearest() -> void:
	var candidates: Array[Ship] = _target_candidates()
	var hostile: Array[Ship] = candidates.filter(func(ship: Ship) -> bool: return is_hostile_to(ship))
	if not hostile.is_empty():
		candidates = hostile
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
		if ship != self and ship.is_active():
			result.append(ship)
	return result


func _positions(ships: Array[Ship]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for ship: Ship in ships:
		result.append(ship.global_position)
	return result


func gov_def() -> GovernmentDef:
	return DataRegistry.get_government(government) if government != "" else null


## G1, G3, A8: would this ship fight `other`? For the player, whether `other`
## treats the player as hostile.
func is_hostile_to(other: Ship) -> bool:
	if other == null or other == self or not is_instance_valid(other):
		return false
	if is_player():
		return other.is_hostile_to(self)
	if _aggressors.has(other):
		return true
	var mine: GovernmentDef = gov_def()
	if other.is_player():
		if mine == null:
			return false
		var provoked: bool = role == "warship" and GameState.is_provoked(government)
		return Relations.hostile_to_player(mine, GameState.get_record(government), provoked)
	return Relations.governments_hostile(mine, other.gov_def())


## Present in space: not destroyed, not docked.
func is_active() -> bool:
	return not health.is_destroyed and not docked and visible


func forget_aggressor(ship: Ship) -> void:
	_aggressors.erase(ship)


func _on_damaged(source: Node) -> void:
	if not source is Ship or source == self or not is_instance_valid(source):
		return
	var attacker: Ship = source
	_last_attacker = attacker
	if not Relations.allied(gov_def(), attacker.gov_def()):
		_aggressors[attacker] = true
	if attacker.is_player():
		GameState.report_player_act(self, "shoot")
		if government != "":
			GameState.provoke(government)
	attacked.emit(attacker)


func _attacked_by_player() -> bool:
	return _last_attacker != null and is_instance_valid(_last_attacker) and _last_attacker.is_player()


func _on_disabled() -> void:
	visual.modulate = DISABLED_TINT
	if _attacked_by_player():
		GameState.report_player_act(self, "disable")


func _on_destroyed() -> void:
	if _attacked_by_player():
		GameState.report_player_act(self, "kill")
	Flash.spawn(get_parent(), global_position, hit_radius * 2.5, Color(1.0, 0.7, 0.3), 0.8)
	ship_destroyed.emit(self)
	hitbox_shape.set_deferred(&"disabled", true)
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
	shape.color = placeholder_colour()
	visual.add_child(shape)


## Placeholder art colour: the player is pale blue, other ships take their
## government's colour, or the radar's neutral colour without one.
func placeholder_colour() -> Color:
	if is_player():
		return Color(0.75, 0.85, 1.0)
	var gov: GovernmentDef = DataRegistry.get_government(government) if government != "" else null
	if gov != null:
		return gov.colour.lerp(Color.WHITE, 0.25)
	return Color.html(DataRegistry.settings["radar"]["colours"]["neutral"])


## A1: docking hides the ship and takes it out of play; undocking restores it.
func set_docked(value: bool) -> void:
	docked = value
	visible = not value
	hitbox_shape.set_deferred(&"disabled", value)
	body.set_physics_process(not value)
	if value:
		body.state.velocity = Vector2.ZERO
		set_target(null)


## Places the ship and resets interpolation (spawns, take-offs, arrivals).
func place(at: Vector2, rotation_value: float, velocity: Vector2 = Vector2.ZERO) -> void:
	body.state = FlightState.new(at, velocity, rotation_value)
	position = at
	rotation = rotation_value
	reset_physics_interpolation()
