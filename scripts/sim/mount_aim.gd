class_name MountAim
extends RefCounted
## V3–V4: barrel angles for pivot and turret mounts. Angles are radians
## relative to the ship's heading (0 = straight ahead, positive clockwise,
## the same convention as FlightModel and Aim).


## Angle of world `direction` relative to a ship at `ship_rotation`.
static func relative_angle(ship_rotation: float, direction: Vector2) -> float:
	return angle_difference(ship_rotation, Aim.rotation_of(direction))


## Clamps `angle` into an arc of `arc_degrees` total centred on the heading.
static func clamp_to_arc(angle: float, arc_degrees: float) -> float:
	if arc_degrees >= 360.0:
		return wrapf(angle, -PI, PI)
	var half: float = deg_to_rad(arc_degrees) / 2.0
	return clampf(wrapf(angle, -PI, PI), -half, half)


## True if `angle` lies within the arc.
static func in_arc(angle: float, arc_degrees: float) -> bool:
	return arc_degrees >= 360.0 or absf(wrapf(angle, -PI, PI)) <= deg_to_rad(arc_degrees) / 2.0 + 0.000001


## Turns `current` toward `desired` by at most `traverse_degrees` × delta.
## Inside a limited arc the barrel can't swing through the back, so it moves
## the short way within the arc; a full 360° turret takes the shortest way.
static func step(current: float, desired: float, traverse_degrees: float, arc_degrees: float, delta: float) -> float:
	var max_turn: float = deg_to_rad(traverse_degrees) * delta
	var diff: float
	if arc_degrees >= 360.0:
		diff = angle_difference(current, desired)
	else:
		diff = clamp_to_arc(desired, arc_degrees) - clamp_to_arc(current, arc_degrees)
	return clamp_to_arc(current + clampf(diff, -max_turn, max_turn), arc_degrees)


## A12 covering fire: can this mount hit a target at `relative` (radians from
## the heading) without the ship turning? Guided launchers always can; pivots
## and turrets inside their arc; fixed mounts within `fixed_degrees` of the nose.
static func can_cover(tracks: bool, guided: bool, relative: float, arc_degrees: float, fixed_degrees: float) -> bool:
	if guided:
		return true
	if tracks:
		return in_arc(relative, arc_degrees)
	return absf(wrapf(relative, -PI, PI)) <= deg_to_rad(fixed_degrees)

