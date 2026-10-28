class_name WeaponMounts
extends Node2D
## C1–C4: the ship's equipped weapons, each assigned an exit point of its kind
## (shared round-robin when there are more weapons than points). Primary fire
## drives guns, turrets and beams; secondary fire launches guided missiles.


class Mount:
	var weapon: WeaponDef
	var point: Vector2
	var cooldown: float = 0.0
	var beam: Beam = null


var mounts: Array[Mount] = []

@onready var ship: Ship = get_parent()


func setup(ship_def: ShipDef) -> void:
	for mount: Mount in mounts:
		if mount.beam != null:
			mount.beam.queue_free()
	mounts.clear()
	var used: Dictionary = {}
	for loadout: Dictionary in ship_def.default_weapons:
		var weapon: WeaponDef = DataRegistry.get_weapon(loadout["weapon"])
		var points: Array = ship_def.hardpoints[weapon.kind]
		for i: int in loadout["count"]:
			var mount := Mount.new()
			mount.weapon = weapon
			var n: int = used.get(weapon.kind, 0)
			mount.point = points[n % points.size()]
			used[weapon.kind] = n + 1
			if weapon.kind == "beam":
				mount.beam = Beam.new()
				mount.beam.weapon = weapon
				mount.beam.position = mount.point
				add_child(mount.beam)
			mounts.append(mount)


func _physics_process(delta: float) -> void:
	var input: FlightInput = ship.get_flight_input()
	for mount: Mount in mounts:
		mount.cooldown = maxf(mount.cooldown - delta, 0.0)
		var wants: bool = input.fire_secondary if mount.weapon.kind == "guided" else input.fire_primary
		if mount.beam != null:
			if wants:
				mount.beam.fire(ship, _exclude(), delta)
			else:
				mount.beam.stop()
		elif wants and mount.cooldown <= 0.0 and _fire(mount):
			mount.cooldown = mount.weapon.reload


## Returns false when the shot was not taken (turret target outside its arc).
func _fire(mount: Mount) -> bool:
	var at: Vector2 = ship.global_transform * mount.point
	var heading: Vector2 = FlightModel.heading(ship.global_rotation)
	var direction: Vector2 = heading
	var target: Ship = ship.get_target()
	if mount.weapon.kind == "turret" and target != null:
		var shot_frame_velocity: Vector2 = ship.get_velocity() if mount.weapon.inherit_velocity else Vector2.ZERO
		direction = Aim.intercept_direction(at, target.global_position, target.get_velocity() - shot_frame_velocity, mount.weapon.speed)
		if not Aim.within_arc(ship.global_rotation, direction, mount.weapon.arc):
			return false
	var shots: Node = get_tree().get_first_node_in_group(&"shots")
	Projectile.fire(shots, mount.weapon, at, direction, ship.get_velocity(), ship, _exclude(),
		target if mount.weapon.kind == "guided" else null)
	return true


func _exclude() -> Array[RID]:
	return [ship.hitbox.get_rid()]


## AI helpers: longest reach of primary weapons (guns, turrets, beams), and
## of guided weapons; speed of the first gun or turret shot (for lead).
func primary_range() -> float:
	return _reach(func(kind: String) -> bool: return kind != "guided")


func guided_range() -> float:
	return _reach(func(kind: String) -> bool: return kind == "guided")


func primary_shot_speed() -> float:
	for mount: Mount in mounts:
		if mount.weapon.kind == "gun" or mount.weapon.kind == "turret":
			return mount.weapon.speed
	return 0.0


func has_turret() -> bool:
	return mounts.any(func(m: Mount) -> bool: return m.weapon.kind == "turret")


func _reach(want: Callable) -> float:
	var best: float = 0.0
	for mount: Mount in mounts:
		if not want.call(mount.weapon.kind):
			continue
		best = maxf(best, mount.weapon.reach())
	return best
