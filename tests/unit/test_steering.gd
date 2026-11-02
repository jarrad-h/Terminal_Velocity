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


func test_coasting_ships_face_where_they_are_going() -> void:
	# At cruise along +x but facing up: a small error isn't chased sideways.
	var s := FlightState.new(Vector2.ZERO, Vector2(300, 10), 0.0)
	var input: FlightInput = Steering.toward_velocity(s, _stats(), Vector2(300, 0), 35.0, DT, 24.0)
	assert_false(input.thrust, "within the deadband: no burn")
	assert_true(input.turn > 0.0, "turns towards the direction of travel (right)")


func test_formation_slots() -> void:
	assert_vec_near(Formation.offset(0, "wedge", 100.0), Vector2.ZERO, "the leader's own slot")
	assert_vec_near(Formation.offset(1, "wedge", 100.0), Vector2(100, 100), "wedge: first follower behind right")
	assert_vec_near(Formation.offset(2, "wedge", 100.0), Vector2(-100, 100), "second behind left")
	assert_vec_near(Formation.offset(3, "wedge", 100.0), Vector2(200, 200), "next row back")
	assert_vec_near(Formation.offset(2, "line", 100.0), Vector2(0, 200), "line: one behind another")
	assert_vec_near(Formation.slot_position(1, "line", 100.0, Vector2(50, 50), PI / 2.0), Vector2(-50, 50), "rotates with the leader (facing right: behind is left)")
