class_name FlightModel
extends RefCounted
## Pure kinematic flight maths (F1–F3): fixed-rate turning, thrust along the
## heading, a hard speed cap and no drag, so ships drift when not thrusting.


## Returns the state after `delta` seconds; `state` is not modified.
static func step(state: FlightState, input: FlightInput, stats: FlightStats, delta: float) -> FlightState:
	var next: FlightState = state.copy()
	var max_turn: float = deg_to_rad(stats.turn_rate) * delta

	if input.turn != 0.0:
		next.rotation += clampf(input.turn, -1.0, 1.0) * max_turn
	elif input.reverse and not next.velocity.is_zero_approx():
		var diff: float = angle_difference(next.rotation, retrograde_rotation(next.velocity))
		next.rotation += clampf(diff, -max_turn, max_turn)
	next.rotation = wrapf(next.rotation, -PI, PI)

	if input.thrust:
		next.velocity += heading(next.rotation) * stats.accel * delta
	next.velocity = next.velocity.limit_length(stats.top_speed)

	next.position += next.velocity * delta
	return next


## Unit vector the ship faces at `rotation`.
static func heading(rotation: float) -> Vector2:
	return Vector2.UP.rotated(rotation)


## Rotation that faces directly against `velocity`.
static func retrograde_rotation(velocity: Vector2) -> float:
	return wrapf((-velocity).angle() + PI / 2.0, -PI, PI)
