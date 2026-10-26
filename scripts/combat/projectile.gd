class_name Projectile
extends Node2D
## C1–C3: a gun or turret shot, or a guided missile. Moves kinematically and
## ray-tests its path each physics frame so fast shots can't tunnel.

var weapon: WeaponDef
var velocity: Vector2
var shooter: Node = null
## Missiles only: what to home on (null = fly straight).
var target: Ship = null
var _life: float = 0.0
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
	shot.target = p_target
	shot._exclude = exclude
	shot._life = p_weapon.shot_lifetime()
	parent.add_child(shot)
	shot.reset_physics_interpolation()
	return shot


func _physics_process(delta: float) -> void:
	if weapon.kind == "guided":
		if target != null and is_instance_valid(target) and not target.health.is_destroyed:
			rotation = Aim.homing_rotation(rotation, position, target.global_position, weapon.turn_rate, delta)
		velocity = FlightModel.heading(rotation) * weapon.speed
	var next: Vector2 = position + velocity * delta
	var hit: Dictionary = HitQuery.ray(self, position, next, _exclude)
	if not hit.is_empty():
		hit["target"].health.apply_damage(weapon.damage_shield, weapon.damage_armor, shooter if is_instance_valid(shooter) else null)
		Flash.spawn(get_parent(), hit["position"], 6.0 if weapon.kind != "guided" else 18.0, weapon.colour, 0.25)
		queue_free()
		return
	position = next
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	if weapon.kind == "guided":
		draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(3, 4), Vector2(-3, 4)]), weapon.colour)
	else:
		draw_line(Vector2(0, -6), Vector2(0, 6), weapon.colour, 2.0)
