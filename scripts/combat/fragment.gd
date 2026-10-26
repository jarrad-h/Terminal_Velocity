class_name Fragment
extends RigidBody2D
## L4: a cosmetic piece thrown off destroyed scenery. No collision shape, no
## gravity: it tumbles away, fades and frees itself. Ships pass through it.

var lifetime: float = 6.0
var _age: float = 0.0


static func spawn(parent: Node, def: SceneryDef, at: Vector2, base_velocity: Vector2, speed: float, p_lifetime: float, look_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var piece := Fragment.new()
	piece.gravity_scale = 0.0
	piece.lifetime = p_lifetime
	piece.global_position = at
	piece.rotation = rng.randf() * TAU
	piece.linear_velocity = base_velocity + Vector2.from_angle(rng.randf() * TAU) * speed
	piece.angular_velocity = deg_to_rad(rng.randf_range(def.spin.x, def.spin.y) + rng.randf_range(-90.0, 90.0))
	piece.collision_layer = 0
	piece.collision_mask = 0
	piece.add_child(Scenery.build_visual(def, rng.randf_range(def.size.x, def.size.y), rng.randi()))
	parent.add_child(piece)
	piece.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_age += delta
	modulate.a = clampf(1.0 - _age / lifetime, 0.0, 1.0)
	if _age >= lifetime:
		queue_free()
