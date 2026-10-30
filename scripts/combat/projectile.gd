class_name Projectile
extends Node2D
## C1–C3: a gun or turret shot, or a guided missile. Moves kinematically and
## ray-tests its path each physics frame so fast shots can't tunnel.

var weapon: WeaponDef
var velocity: Vector2
var shooter: Node = null
## C11: the shooter's side, recorded at launch.
var shooter_is_player: bool = false
var shooter_government: String = ""
## Missiles only: what to home on (null = fly straight).
var target: Ship = null
var _life: float = 0.0
## C12: path length so far.
var _travelled: float = 0.0
var _exclude: Array[RID] = []


static func fire(parent: Node, p_weapon: WeaponDef, at: Vector2, direction: Vector2, base_velocity: Vector2, p_shooter: Node, exclude: Array[RID], p_target: Ship = null) -> Projectile:
	var shot := Projectile.new()
	shot.weapon = p_weapon
	shot.position = at
	shot.rotation = Aim.rotation_of(direction)
	shot.velocity = direction * p_weapon.speed
	if p_weapon.kind != "guided" and p_weapon.inherit_velocity:
		shot.velocity += base_velocity
	shot.shooter = p_shooter
	if p_shooter is Ship:
		shot.shooter_is_player = (p_shooter as Ship).is_player()
		shot.shooter_government = (p_shooter as Ship).government
	shot.target = p_target
	shot._exclude = exclude
	shot._life = p_weapon.shot_lifetime()
	parent.add_child(shot)
	shot.reset_physics_interpolation()
	return shot


func _init() -> void:
	material = LitSprite.unshaded_material()  # V6: full brightness, not lit or darkened


func _physics_process(delta: float) -> void:
	if weapon.kind == "guided":
		if is_instance_valid(target) and not target.health.is_destroyed:
			rotation = Aim.homing_rotation(rotation, position, target.global_position, weapon.turn_rate, delta)
		velocity = FlightModel.heading(rotation) * weapon.speed
	var next: Vector2 = position + velocity * delta
	var hit: Dictionary = HitQuery.ray(self, position, next, _exclude)
	if not hit.is_empty():
		var step_fraction: float = position.distance_to(hit["position"]) / maxf(position.distance_to(next), 0.001)
		var at_distance: float = _travelled + weapon.speed * delta * step_fraction
		var scale: float = HitQuery.damage_scale(shooter_is_player, shooter_government, hit["target"]) * weapon.falloff_at(at_distance)
		if scale > 0.0:
			hit["target"].health.apply_damage(weapon.damage_shield * scale, weapon.damage_armor * scale, shooter if is_instance_valid(shooter) else null)
		Flash.spawn(get_parent(), hit["position"], 6.0 if weapon.kind != "guided" else 18.0, weapon.colour, 0.25)
		queue_free()
		return
	# C12: falloff follows the shot's own travel (speed × time), not world
	# distance, so it doesn't depend on how fast the shooter was moving.
	_travelled += weapon.speed * delta
	position = next
	# C12: fade with damage falloff (never fully invisible).
	if weapon.falloff_start_pct < 100.0:
		modulate.a = lerpf(0.2, 1.0, weapon.falloff_at(_travelled))
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	if weapon.kind == "guided":
		draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(3, 4), Vector2(-3, 4)]), weapon.colour)
	else:
		draw_line(Vector2(0, -6), Vector2(0, 6), weapon.colour, 2.0)
