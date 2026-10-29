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
## Bounding radius around the ship centre (flashes, markers), px. The hitbox
## itself is a capsule (V2).
var hit_radius: float = 0.0
## V1: game.json art_scale, applied to sprite, hitbox, hardpoints and engines.
var art_scale: float = 1.0
var controller: Node = null
## Government ID ("" = none). Set at spawn.
var government: String = ""
## AI role from its pool ("trader", "warship", "pirate"); "" for the player and idle ships.
var role: String = ""
## A1: a docked trader is hidden, untargetable and ignored by AI.
var docked: bool = false
## G2: acts the player has already been charged for against this ship.
var player_acts: Dictionary = {}
## C9: credits aboard, rolled the first time the player boards (-1 = not yet).
var credits_aboard: int = -1
## C9: the player took the credits; Assist is no longer offered.
var looted: bool = false
## A8: the player's damage so far, as % of total shield + armour; drains over time.
var grievance: float = 0.0
## A8: personality's tolerance factor (set by the AI controller).
var tolerance_factor: float = 1.0
## Ships this one treats as hostile because they attacked it: non-allied AI
## ships at once, the player once grievance passes tolerance (A8).
var _aggressors: Dictionary = {}
var _last_attacker: Ship = null
var _scuttled: bool = false
static var _DEFAULT_GOV: GovernmentDef = GovernmentDef.parse(DefReader.new({}, "", []))
var _target: Ship = null
var _target_id: int = 0

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
## keeps position, velocity and heading. A ship swap (D2) restores full shield
## and armour; a data reload (D8, `keep_health`) keeps current damage and the
## disabled state, so reloading never heals or revives anything.
func setup(ship_def: ShipDef, keep_health: bool = false) -> void:
	def = ship_def
	art_scale = float(DataRegistry.settings["art_scale"])
	hit_radius = def.bounding_radius() * art_scale
	body.stats = FlightStats.from_ship_def(def)
	var capsule := CapsuleShape2D.new()
	capsule.radius = def.hit_size.x * art_scale / 2.0
	capsule.height = def.hit_size.y * art_scale
	hitbox_shape.shape = capsule
	hitbox_shape.position = def.hit_offset * art_scale
	weapons.setup(def, art_scale)
	_build_visual()
	if keep_health:
		health.retune(def.shield, def.armor, def.shield_regen, def.disable_armor_pct / 100.0, def.shield_recharge_delay)
		if health.is_disabled:
			set_tint(DISABLED_TINT)
	else:
		health.setup(def.shield, def.armor, def.shield_regen, def.disable_armor_pct / 100.0, def.shield_recharge_delay)
		hitbox_shape.set_deferred(&"disabled", false)
		visible = true
		set_tint(Color.WHITE)
		body.set_physics_process(true)
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


## C8: the selected target, or null once it is gone. Tracked by instance ID:
## in Godot 4 a freed object compares equal to null, so `_target != null`
## can't tell "no target" from "target was freed".
func get_target() -> Ship:
	if _target_id != 0 and (not is_instance_id_valid(_target_id) or not _target.is_active()):
		_target = null
		_target_id = 0
		target_changed.emit(null)
	return _target if _target_id != 0 else null


func set_target(ship: Ship) -> void:
	var new_id: int = ship.get_instance_id() if ship != null else 0
	if new_id == _target_id:
		return
	_target = ship
	_target_id = new_id
	target_changed.emit(ship)


## C8: nearest ship (only hostile ones when `hostile_only`). With no
## candidates the current target is kept.
func target_nearest(hostile_only: bool) -> void:
	var candidates: Array[Ship] = _target_candidates(hostile_only)
	var index: int = Targeting.nearest(global_position, _positions(candidates))
	if index >= 0:
		set_target(candidates[index])


## C8: next target after the current one, nearest first, wrapping round.
func cycle_target(hostile_only: bool) -> void:
	var candidates: Array[Ship] = _target_candidates(hostile_only)
	var index: int = Targeting.cycle(global_position, _positions(candidates), candidates.find(get_target()))
	if index >= 0:
		set_target(candidates[index])


func _target_candidates(hostile_only: bool = false) -> Array[Ship]:
	var result: Array[Ship] = []
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node
		if ship != self and ship.is_active() and (not hostile_only or is_hostile_to(ship)):
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
		return Relations.hostile_to_player(mine, GameState.get_record(government))
	return Relations.governments_hostile(mine, other.gov_def())


## Present in space: not destroyed, not docked.
func is_active() -> bool:
	return not health.is_destroyed and not docked and visible


## G5: "hostile", "angry", "friendly" or "neutral" towards the player.
func standing_to(player_ship: Ship) -> String:
	var record: float = GameState.get_record(government) if government != "" else 0.0
	return Relations.standing(player_ship.is_hostile_to(self), grievance, gov_def(), record)


func forget_aggressor(ship: Ship) -> void:
	_aggressors.erase(ship)


func _on_damaged(source: Node, amount: float) -> void:
	if not source is Ship or source == self or not is_instance_valid(source):
		return
	var attacker: Ship = source
	_last_attacker = attacker
	if attacker.is_player():
		_on_player_damage(attacker, amount)
	elif not Relations.allied(gov_def(), attacker.gov_def()):
		_aggressors[attacker] = true
	attacked.emit(attacker)


## A8 + G2: accidental fire is forgiven; past the tolerance this ship (only)
## turns hostile and the attack penalty is charged.
func _on_player_damage(player_ship: Ship, amount: float) -> void:
	if is_hostile_to(player_ship):
		GameState.report_player_act(self, "shoot")
		return
	grievance = Grievance.add(grievance, amount, health.max_shield + health.max_armor)
	if Grievance.exceeded(grievance, _tolerance()):
		_aggressors[player_ship] = true
		GameState.post_message("The %s turns hostile" % def.name, "standing")  # H4, A8
		GameState.report_player_act(self, "shoot")


## Ships with no government use the GovernmentDef defaults (documented in data/README.md).
func _leniency_gov() -> GovernmentDef:
	var mine: GovernmentDef = gov_def()
	return mine if mine != null else _DEFAULT_GOV


func _tolerance() -> float:
	return Grievance.tolerance(_leniency_gov().tolerance_pct, tolerance_factor)


func _physics_process(delta: float) -> void:
	if grievance > 0.0:
		grievance = Grievance.decay(grievance, _leniency_gov().forgiveness_pct_per_s, delta)


func _attacked_by_player() -> bool:
	return is_instance_valid(_last_attacker) and _last_attacker.is_player()


func _on_disabled() -> void:
	set_tint(DISABLED_TINT)
	if _attacked_by_player():
		GameState.report_player_act(self, "disable")
		GameState.post_message("%s disabled" % def.name, "combat")  # H4


func _on_destroyed() -> void:
	if _attacked_by_player():
		GameState.report_player_act(self, "kill")
		if not _scuttled:
			GameState.post_message("%s destroyed" % def.name, "combat")  # H4
	Flash.spawn(get_parent(), global_position, hit_radius * 2.5, Color(1.0, 0.7, 0.3), 0.8)
	ship_destroyed.emit(self)
	hitbox_shape.set_deferred(&"disabled", true)
	if is_player():
		# C10: the escape pod and rescue are handled by PlayerActions.
		visible = false
		body.set_physics_process(false)
		return
	queue_free()


func _on_data_reloaded() -> void:
	var fresh: ShipDef = DataRegistry.get_ship(def.id)
	if fresh != null:
		setup(fresh, true)


func _build_visual() -> void:
	for child: Node in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	if not def.engines.is_empty():
		var glow := EngineGlow.new()
		glow.name = "EngineGlow"
		for p: Vector2 in def.engines:
			glow.points.append(p * art_scale)
		glow.colour = def.engine_colour
		glow.size = def.engine_size * art_scale
		visual.add_child(glow)
	var sprite_path: String = SPRITE_DIR.path_join(def.sprite)
	if def.sprite != "" and ResourceLoader.exists(sprite_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(sprite_path)
		sprite.scale = Vector2.ONE * art_scale
		visual.add_child(sprite)
		return
	# Placeholder art: an arrowhead pointing along the heading (up), sized to the hull.
	var w: float = def.hit_size.x * art_scale / 2.0
	var l: float = def.hit_size.y * art_scale / 2.0
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2(0.0, -l), Vector2(w * 0.7, l * 0.8), Vector2(0.0, l * 0.4), Vector2(-w * 0.7, l * 0.8),
	])
	shape.position = def.hit_offset * art_scale
	shape.color = placeholder_colour()
	visual.add_child(shape)


## Disabled tint (C7) on the hull and its turrets.
func set_tint(colour: Color) -> void:
	visual.modulate = colour
	weapons.modulate = colour


## V2: edge-to-edge distance between this hull and `other` (capsules).
func hull_gap(other: Ship) -> float:
	return Capsule.gap(global_position, global_rotation, def.hit_size * art_scale, def.hit_offset * art_scale,
		other.global_position, other.global_rotation, other.def.hit_size * other.art_scale, other.def.hit_offset * other.art_scale)


## Half the hull's width, px (placing ships alongside).
func hull_half_width() -> float:
	return def.hit_size.x * art_scale / 2.0


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


## C9: credits multiplier from the ship's AI pool (1 for ships without one).
func wealth_factor() -> float:
	return (controller as AIController).pool.wealth_factor if controller is AIController else 1.0


## C9 Assist: back on its feet; forgives the player.
func recover(armor_pct: float) -> void:
	health.recover(armor_pct)
	set_tint(Color.WHITE)
	grievance = 0.0
	for other: Variant in _aggressors.keys():
		if is_instance_valid(other) and (other as Ship).is_player():
			_aggressors.erase(other)


## C9: Scuttle — destroyed by the player (kill penalty applies).
func scuttle_by(player_ship: Ship) -> void:
	_last_attacker = player_ship
	_scuttled = true  # PlayerActions posts its own "scuttled" message
	health.force_destroy()
