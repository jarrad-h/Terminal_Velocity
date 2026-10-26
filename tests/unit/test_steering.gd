extends TvTest
## AI steering drives the real flight model (A1–A3).

const DT: float = 1.0 / 60.0


func _stats() -> FlightStats:
	return FlightStats.new(200.0, 300.0, 150.0)


## Flies `seconds` toward a stop at `target`; returns the final state.
func _arrive(start: FlightState, target: Vector2, seconds: float) -> FlightState:
	var s: FlightState = start
	for i: int in roundi(seconds / DT):
		var desired: Vector2 = Steering.arrive_velocity(s, _stats(), target)
		s = FlightModel.step(s, Steering.toward_velocity(s, _stats(), desired, 35.0, DT), _stats(), DT)
	return s


func test_arrive_stops_at_the_target() -> void:
	var s: FlightState = _arrive(FlightState.new(), Vector2(2000, 500), 25.0)
	assert_true(s.position.distance_to(Vector2(2000, 500)) < 40.0, "ends near the target (%s)" % s.position)
	assert_true(s.velocity.length() < 60.0, "slow enough to land (%f)" % s.velocity.length())


func test_arrive_from_moving_the_wrong_way() -> void:
	var s: FlightState = _arrive(FlightState.new(Vector2.ZERO, Vector2(-300, 0), 0.0), Vector2(1500, 0), 30.0)
	assert_true(s.position.distance_to(Vector2(1500, 0)) < 40.0, "turns round and arrives (%s)" % s.position)


func test_arrive_speed_shrinks_to_zero() -> void:
	assert_near(Steering.arrive_speed(0.0, _stats()), 0.0, "at the target")
	assert_true(Steering.arrive_speed(100.0, _stats()) < Steering.arrive_speed(1000.0, _stats()), "slower when closer")
	assert_near(Steering.arrive_speed(1000000.0, _stats()), 300.0, "capped at top speed")


func test_toward_velocity_turns_before_thrusting() -> void:
	var s := FlightState.new()  # facing up
	var input: FlightInput = Steering.toward_velocity(s, _stats(), Vector2(300, 0), 35.0, DT)
	assert_true(input.turn > 0.0, "turns right toward +x")
	assert_true(not input.thrust, "doesn't thrust 90° off")
	var aligned: FlightInput = Steering.toward_velocity(FlightState.new(Vector2.ZERO, Vector2.ZERO, PI / 2.0), _stats(), Vector2(300, 0), 35.0, DT)
	assert_true(aligned.thrust, "thrusts once aligned")


func test_turn_does_not_overshoot() -> void:
	var input: FlightInput = Steering.face(FlightState.new(), _stats(), Vector2(0.01, -1.0), DT)
	assert_true(absf(input.turn) < 1.0, "small correction for a small angle")


func test_aligned_for_firing() -> void:
	assert_true(Steering.aligned(0.0, Vector2(0, -1), 8.0), "dead ahead")
	assert_true(not Steering.aligned(0.0, Vector2(1, -1), 8.0), "45° off")
