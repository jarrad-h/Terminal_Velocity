class_name Steering
extends RefCounted
## AI steering (A1–A3): turns a goal into the same FlightInput the player's
## controller makes, so AI ships obey the flight model exactly. Pure.


## Turn toward the velocity change needed and thrust once roughly aligned.
## `thrust_angle` (degrees): how closely aligned before thrusting.
static func toward_velocity(state: FlightState, stats: FlightStats, desired: Vector2, thrust_angle: float, delta: float) -> FlightInput:
	var input := FlightInput.new()
	var dv: Vector2 = desired - state.velocity
	if dv.length() <= stats.accel * delta:
		return input
	var diff: float = angle_difference(state.rotation, Aim.rotation_of(dv))
	input.turn = _turn_amount(diff, stats, delta)
	input.thrust = absf(diff) <= deg_to_rad(thrust_angle)
	return input


## Turn only, to face `direction`.
static func face(state: FlightState, stats: FlightStats, direction: Vector2, delta: float) -> FlightInput:
	var input := FlightInput.new()
	if direction.is_zero_approx():
		return input
	input.turn = _turn_amount(angle_difference(state.rotation, Aim.rotation_of(direction)), stats, delta)
	return input


## Fastest speed from which the ship can still stop within `distance`,
## allowing time to turn round (180° at turn_rate) before braking.
static func arrive_speed(distance: float, stats: FlightStats) -> float:
	if stats.accel <= 0.0 or distance <= 0.0:
		return 0.0
	var turn_time: float = PI / maxf(deg_to_rad(stats.turn_rate), 0.0001)
	var a: float = stats.accel
	return minf(stats.top_speed, a * (-turn_time + sqrt(turn_time * turn_time + 2.0 * distance / a)))


## Velocity that brings the ship to rest at `target` (or matching `target_velocity`).
static func arrive_velocity(state: FlightState, stats: FlightStats, target: Vector2, target_velocity: Vector2 = Vector2.ZERO) -> Vector2:
	var offset: Vector2 = target - state.position
	if offset.is_zero_approx():
		return target_velocity
	return target_velocity + offset.normalized() * arrive_speed(offset.length(), stats)


## True when the heading is within `fire_angle` degrees of `direction`.
static func aligned(rotation: float, direction: Vector2, fire_angle: float) -> bool:
	return not direction.is_zero_approx() and absf(angle_difference(rotation, Aim.rotation_of(direction))) <= deg_to_rad(fire_angle)


static func _turn_amount(diff: float, stats: FlightStats, delta: float) -> float:
	var max_turn: float = deg_to_rad(stats.turn_rate) * delta
	if max_turn <= 0.0:
		return 0.0
	return clampf(diff / max_turn, -1.0, 1.0)
