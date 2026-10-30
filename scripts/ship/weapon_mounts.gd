class_name WeaponMounts
extends Node2D
## C1–C4, V3–V4: the ship's installed weapons, one per hardpoint. Fixed mounts
## fire along the heading; pivot and turret mounts swing a barrel toward the
## selected target's lead point within their arc at their traverse rate, and
## shots leave along the barrel. Primary fire drives lasers, flak and beams;
## secondary fire launches guided missiles.


class Mount:
	var weapon: WeaponDef
	var hardpoint: HardpointDef
	## The item's mount type (fixed, pivot, turret, launcher).
	var mount: String
	## Exit point in ship space (art px × art_scale).
	var point: Vector2
	var arc: float = 0.0
	var traverse: float = 0.0
	## Barrel angle relative to the heading, radians (MountAim).
	var angle: float = 0.0
	var cooldown: float = 0.0
	## Rotates with the barrel; parent of the beam and the turret sprite.
	var barrel: Node2D = null
	var beam: Beam = null

	func tracks() -> bool:
		return mount == "pivot" or mount == "turret"


var mounts: Array[Mount] = []
var _fire_tolerance: float = 0.0

@onready var ship: Ship = get_parent()


func setup(ship_def: ShipDef, art_scale: float) -> void:
	for mount: Mount in mounts:
		remove_child(mount.barrel)  # free the name for the rebuilt barrel
		mount.barrel.queue_free()
	mounts.clear()
	var settings: Dictionary = DataRegistry.settings
	_fire_tolerance = deg_to_rad(float(settings["mounts"]["fire_tolerance"]))
	for entry: LoadoutEntry in ship_def.loadout:
		var mount := Mount.new()
		mount.weapon = DataRegistry.get_weapon(entry.weapon)
		mount.hardpoint = ship_def.hardpoint(entry.hardpoint)
		mount.mount = entry.mount
		mount.point = mount.hardpoint.pos * art_scale
		mount.arc = mount.hardpoint.arc_degrees(settings)
		mount.traverse = mount.hardpoint.traverse_degrees(settings)
		mount.barrel = Node2D.new()
		mount.barrel.name = "Mount_" + mount.hardpoint.id
		mount.barrel.position = mount.point
		add_child(mount.barrel)
		if mount.mount == "turret":
			_add_turret_sprite(mount, settings, art_scale)
		if mount.weapon.kind == "beam":
			mount.beam = Beam.new()
			mount.beam.weapon = mount.weapon
			mount.barrel.add_child(mount.beam)
		mounts.append(mount)


## V4: the turret drawn on its ring; image centre is the pivot, barrels up.
func _add_turret_sprite(mount: Mount, settings: Dictionary, art_scale: float) -> void:
	var key: String = "point_defence" if mount.hardpoint.role == "point_defence" else mount.hardpoint.size
	var path: String = Ship.SPRITE_DIR.path_join(String(settings["mounts"]["turret_sprites"][key]))
	if String(settings["mounts"]["turret_sprites"][key]) == "":
		return  # no turret art for this size (the loader checks named paths exist)
	var sprite: Sprite2D = LitSprite.build(path)  # V6
	sprite.name = "TurretSprite"
	sprite.scale = Vector2.ONE * art_scale
	mount.barrel.add_child(sprite)


func _physics_process(delta: float) -> void:
	var input: FlightInput = ship.get_flight_input()
	var target: Ship = ship.get_target() if ship.can_act() else null
	for mount: Mount in mounts:
		mount.cooldown = maxf(mount.cooldown - delta, 0.0)
		var desired: float = _desired_angle(mount, target)
		if mount.tracks():
			mount.angle = MountAim.step(mount.angle, desired, mount.traverse, mount.arc, delta)
			mount.barrel.rotation = mount.angle
		var wants: bool = input.fire_secondary if mount.weapon.kind == "guided" else input.fire_primary
		wants = wants and _ready_to_fire(mount, target, desired)
		if mount.beam != null:
			if wants:
				mount.beam.fire(ship, _exclude(), delta)
			else:
				mount.beam.stop()
		elif wants and mount.cooldown <= 0.0:
			_fire(mount, target)
			mount.cooldown = mount.weapon.reload


## Barrel angle the mount is trying to reach: the target's lead point
## (clamped into the arc), or straight ahead with no target.
func _desired_angle(mount: Mount, target: Ship) -> float:
	if not mount.tracks() or target == null:
		return 0.0
	var at: Vector2 = ship.global_transform * mount.point
	var shot_frame_velocity: Vector2 = ship.get_velocity() if mount.weapon.inherit_velocity else Vector2.ZERO
	var speed: float = mount.weapon.speed if mount.weapon.kind == "projectile" else 0.0
	var direction: Vector2 = Aim.intercept_direction(at, target.global_position, target.get_velocity() - shot_frame_velocity, speed)
	return MountAim.relative_angle(ship.global_rotation, direction)


## Pivots always fire (held at the arc edge when the target is outside it).
## A turret holds fire while its target is outside its arc or its barrel is
## still swinging onto the aim point.
func _ready_to_fire(mount: Mount, target: Ship, desired: float) -> bool:
	if mount.mount != "turret":
		return true
	if target != null and not MountAim.in_arc(desired, mount.arc):
		return false
	return absf(angle_difference(mount.angle, MountAim.clamp_to_arc(desired, mount.arc))) <= _fire_tolerance


func _fire(mount: Mount, target: Ship) -> void:
	var at: Vector2 = ship.global_transform * mount.point
	var direction: Vector2 = FlightModel.heading(ship.global_rotation + mount.angle)
	var shots: Node = get_tree().get_first_node_in_group(&"shots")
	Projectile.fire(shots, mount.weapon, at, direction, ship.get_velocity(), ship, _exclude(),
		target if mount.weapon.kind == "guided" else null)


func _exclude() -> Array[RID]:
	return [ship.hitbox.get_rid()]


## AI helpers: longest reach of primary weapons (projectiles, beams), and of
## guided weapons; speed of the first projectile (for lead).
func primary_range() -> float:
	return _reach(func(kind: String) -> bool: return kind != "guided")


func guided_range() -> float:
	return _reach(func(kind: String) -> bool: return kind == "guided")


func primary_shot_speed() -> float:
	for mount: Mount in mounts:
		if mount.weapon.kind == "projectile":
			return mount.weapon.speed
	return 0.0


## AI: how far off the nose (degrees, either side) the ship's primary
## weapons can still bring fire to bear: 180 with a full turret, half the
## widest pivot or turret arc otherwise, 0 with fixed weapons only.
func tracking_slack() -> float:
	var best: float = 0.0
	for mount: Mount in mounts:
		if mount.tracks() and mount.weapon.kind != "guided":
			best = maxf(best, minf(mount.arc, 360.0) / 2.0)
	return best


func _reach(want: Callable) -> float:
	var best: float = 0.0
	for mount: Mount in mounts:
		if not want.call(mount.weapon.kind):
			continue
		best = maxf(best, mount.weapon.reach())
	return best
