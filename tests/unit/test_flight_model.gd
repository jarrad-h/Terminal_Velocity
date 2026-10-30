extends TvTest
## F1–F3: flight maths.

const DT: float = 1.0 / 60.0


func _stats() -> FlightStats:
	return FlightStats.new(300.0, 320.0, 180.0)


func _run(state: FlightState, input: FlightInput, seconds: float) -> FlightState:
	for i: int in roundi(seconds / DT):
		state = FlightModel.step(state, input, _stats(), DT)
	return state


func test_thrust_accelerates_along_heading() -> void:
	var s: FlightState = _run(FlightState.new(), FlightInput.new(true), 0.5)
	assert_vec_near(s.velocity, Vector2(0.0, -150.0), "0.5 s of thrust facing up")


func test_speed_is_capped_at_top_speed() -> void:
	var s: FlightState = _run(FlightState.new(), FlightInput.new(true), 5.0)
	assert_near(s.velocity.length(), 320.0, "speed after long thrust")


func test_ship_drifts_without_input() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2(100.0, 0.0), 1.0)
	var s: FlightState = _run(start, FlightInput.new(), 2.0)
	assert_vec_near(s.velocity, Vector2(100.0, 0.0), "velocity unchanged with no drag")
	assert_vec_near(s.position, Vector2(200.0, 0.0), "position after 2 s drift", 0.01)
	assert_near(s.rotation, 1.0, "rotation unchanged")


func test_turn_rate_is_fixed() -> void:
	var s: FlightState = _run(FlightState.new(), FlightInput.new(false, 1.0), 0.5)
	assert_near(s.rotation, PI / 2.0, "90 degrees after 0.5 s at 180 deg/s")


func test_thrust_after_turn_changes_direction_not_speed_beyond_cap() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2(0.0, -320.0), PI / 2.0)
	var s: FlightState = _run(start, FlightInput.new(true), 1.0)
	assert_true(s.velocity.length() <= 320.0 + 0.001, "cap holds while thrusting sideways")
	assert_true(s.velocity.x > 0.0, "velocity bends toward the new heading")


func test_reverse_turns_to_face_against_velocity() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2(100.0, 0.0), 0.0)
	var s: FlightState = _run(start, FlightInput.new(false, 0.0, true), 2.0)
	assert_vec_near(FlightModel.heading(s.rotation), Vector2(-1.0, 0.0), "heading opposes velocity")


func test_reverse_does_not_overshoot() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2(0.0, 100.0), 0.0)
	# Retrograde is already the current heading (facing up, moving down).
	var s: FlightState = _run(start, FlightInput.new(false, 0.0, true), 1.0)
	assert_near(absf(angle_difference(s.rotation, 0.0)), 0.0, "stays on retrograde")


func test_reverse_with_no_velocity_does_nothing() -> void:
	var s: FlightState = _run(FlightState.new(Vector2.ZERO, Vector2.ZERO, 0.3), FlightInput.new(false, 0.0, true), 1.0)
	assert_near(s.rotation, 0.3, "rotation unchanged when stationary")


func test_manual_turn_overrides_reverse() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2(100.0, 0.0), 0.0)
	var s: FlightState = _run(start, FlightInput.new(false, 1.0, true), 0.25)
	assert_near(s.rotation, PI / 4.0, "turns right despite reverse held")


func test_reverse_plus_thrust_brakes() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2(200.0, 0.0), 0.0)
	var s: FlightState = _run(start, FlightInput.new(true, 0.0, true), 1.0)
	assert_true(s.velocity.length() < 200.0, "speed drops when thrusting against velocity")


func test_step_does_not_modify_input_state() -> void:
	var start := FlightState.new(Vector2.ZERO, Vector2.ZERO, 0.0)
	FlightModel.step(start, FlightInput.new(true, 1.0), _stats(), DT)
	assert_vec_near(start.velocity, Vector2.ZERO, "original state untouched")


## F3: flight values come from the ship definition, one-to-one.
func test_flight_stats_come_from_ship_json() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ships/courier.json"))
	var data: DataSet = DataLoader.load_roots(["res://data"])
	var stats: FlightStats = FlightStats.from_ship_def(data.get_def("ships", "courier"))
	assert_near(stats.accel, float(raw["accel"]), "accel")
	assert_near(stats.top_speed, float(raw["top_speed"]), "top_speed")
	assert_near(stats.turn_rate, float(raw["turn_rate"]), "turn_rate")
	var s: FlightState = FlightState.new()
	for i: int in 600:
		s = FlightModel.step(s, FlightInput.new(true), stats, DT)
	assert_near(s.velocity.length(), float(raw["top_speed"]), "speed caps at the JSON top_speed")


func test_disabled_ship_coasts_to_a_stop() -> void:
	var v := Vector2(300, 400)  # 500 px/s
	var after: Vector2 = FlightModel.coast(v, 30.0, 1.0)
	assert_near(after.length(), 470.0, "C7: loses drag px/s each second")
	assert_vec_near(after.normalized(), v.normalized(), "keeps its direction")
	for i: int in 20:
		after = FlightModel.coast(after, 30.0, 1.0)
	assert_vec_near(after, Vector2.ZERO, "comes to rest, never reverses")
	assert_vec_near(FlightModel.coast(v, 0.0, 1.0), v, "0 drag drifts forever")
