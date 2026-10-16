class_name Aim
extends RefCounted
## C2–C3: pure aiming maths. Rotation convention matches FlightModel:
## 0 faces up (-Y), positive is clockwise.


## Direction to fire so a shot at `shot_speed` meets a target moving at
## `relative_velocity` (target velocity minus any velocity the shot inherits).
## Falls back to aiming straight at the target when no intercept exists.
static func intercept_direction(from: Vector2, target_position: Vector2, relative_velocity: Vector2, shot_speed: float) -> Vector2:
	var d: Vector2 = target_position - from
	if shot_speed <= 0.0 or d.is_zero_approx():
		return d.normalized()
	# |d + v t| = s t  ->  (v.v - s²) t² + 2 (d.v) t + d.d = 0
	var a: float = relative_velocity.dot(relative_velocity) - shot_speed * shot_speed
	var b: float = 2.0 * d.dot(relative_velocity)
	var c: float = d.dot(d)
	var t: float = -1.0
	if absf(a) < 0.000001:
		if b < 0.0:
			t = -c / b
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var root: float = sqrt(disc)
			var t1: float = (-b - root) / (2.0 * a)
			var t2: float = (-b + root) / (2.0 * a)
			t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if t <= 0.0:
		return d.normalized()
	return (d + relative_velocity * t).normalized()


static func rotation_of(direction: Vector2) -> float:
	return wrapf(direction.angle() + PI / 2.0, -PI, PI)


## C2: true if `direction` is within a turret arc (total degrees) centred on the heading.
static func within_arc(heading_rotation: float, direction: Vector2, arc_degrees: float) -> bool:
	if arc_degrees >= 360.0:
		return true
	return absf(angle_difference(heading_rotation, rotation_of(direction))) <= deg_to_rad(arc_degrees) / 2.0


## C3: missile rotation after turning toward the target at a fixed rate.
static func homing_rotation(rotation: float, position: Vector2, target_position: Vector2, turn_rate_degrees: float, delta: float) -> float:
	var max_turn: float = deg_to_rad(turn_rate_degrees) * delta
	var diff: float = angle_difference(rotation, rotation_of(target_position - position))
	return wrapf(rotation + clampf(diff, -max_turn, max_turn), -PI, PI)
