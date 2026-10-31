extends TvTest
## TR2: the hyperspace jump flies itself with the ship's own flight model.

const DT: float = 1.0 / 60.0
const SETTINGS: Dictionary = {"stop_speed": 2.0, "align_tolerance": 1.0, "thrust_angle": 20.0,
	"overdrive_accel_factor": 6.0, "engage_speed_factor": 4.0}


func _stats() -> FlightStats:
	return FlightStats.new(200.0, 300.0, 150.0)


## Runs the sequence like ShipBody does; returns [state, phases seen in order, seconds].
func _fly(seq: JumpSequence, start: FlightState, max_seconds: float, stop_at: JumpSequence.Phase = JumpSequence.Phase.ENGAGED) -> Array:
	var s: FlightState = start
	var phases: Array[int] = [seq.phase]
	var t: float = 0.0
	while t < max_seconds and seq.phase != stop_at and seq.is_active():
		var input: FlightInput = seq.step(s, _stats(), DT)
		s = FlightModel.step(s, input, seq.flight_stats(_stats()), DT)
		t += DT
		if phases[-1] != seq.phase:
			phases.append(seq.phase)
	return [s, phases, t]


func test_full_sequence_stops_turns_counts_down_and_overdrives() -> void:
	# Moving right at full speed, facing up; the destination is also to the
	# right, so the stop burn leaves it facing away and it must turn round.
	var seq := JumpSequence.new(Vector2.RIGHT, 3.0, SETTINGS, _stats())
	var result: Array = _fly(seq, FlightState.new(Vector2.ZERO, Vector2(300, 0), 0.0), 60.0)
	var s: FlightState = result[0]
	var P := JumpSequence.Phase
	assert_true(result[1] == [P.STOPPING, P.ALIGNING, P.COUNTDOWN, P.OVERDRIVE, P.ENGAGED], "phases in order: %s" % [result[1]])
	assert_true(seq.is_engaged(), "hyperdrive engaged")
	assert_true(s.velocity.length() >= 4.0 * 300.0 - 0.1, "beyond the speed cap: %f" % s.velocity.length())
	assert_vec_near(s.velocity.normalized(), Vector2.RIGHT, "leaving along the bearing", 0.02)


func test_ship_comes_to_rest_before_the_countdown() -> void:
	var seq := JumpSequence.new(Vector2.DOWN, 3.0, SETTINGS, _stats())
	var result: Array = _fly(seq, FlightState.new(Vector2.ZERO, Vector2(120, -200), 1.0), 30.0, JumpSequence.Phase.COUNTDOWN)
	var s: FlightState = result[0]
	assert_true(seq.phase == JumpSequence.Phase.COUNTDOWN, "reached the countdown")
	assert_vec_near(s.velocity, Vector2.ZERO, "velocity is zero")
	assert_true(Steering.aligned(s.rotation, Vector2.DOWN, 1.0), "facing the destination bearing")
	assert_near(seq.countdown_left, 3.0, "countdown starts only once stopped and facing", 0.05)


func test_countdown_takes_its_time_and_holds_still() -> void:
	var seq := JumpSequence.new(Vector2.UP, 2.0, SETTINGS, _stats())
	var at_countdown: Array = _fly(seq, FlightState.new(), 10.0, JumpSequence.Phase.COUNTDOWN)
	var before: float = at_countdown[2]
	var result: Array = _fly(seq, at_countdown[0], 10.0, JumpSequence.Phase.OVERDRIVE)
	assert_near(result[2], 2.0, "countdown lasts its data time", 0.05)
	assert_vec_near((result[0] as FlightState).position, (at_countdown[0] as FlightState).position, "no drift during the countdown")
	assert_true(before < 0.1, "already stopped and facing up: straight to the countdown (%f s)" % before)


func test_overdrive_lifts_the_cap_only_while_overdriving() -> void:
	var seq := JumpSequence.new(Vector2.UP, 1.0, SETTINGS, _stats())
	assert_near(seq.flight_stats(_stats()).top_speed, 300.0, "normal cap before overdrive")
	seq.phase = JumpSequence.Phase.OVERDRIVE
	var boosted: FlightStats = seq.flight_stats(_stats())
	assert_near(boosted.top_speed, 1200.0, "cap lifted to the hyperdrive speed")
	assert_near(boosted.accel, 1200.0, "overdrive acceleration")
	assert_false(seq.cancel(), "TR2: committed once the countdown ends")
	seq.abort()
	assert_near(seq.flight_stats(_stats()).top_speed, 300.0, "being disabled stops it and restores the cap")


func test_cancel_stops_the_sequence() -> void:
	var seq := JumpSequence.new(Vector2.UP, 3.0, SETTINGS, _stats())
	seq.cancel()
	assert_false(seq.is_active(), "cancelled")
	assert_false(seq.is_engaged(), "never engages")
	seq.phase = JumpSequence.Phase.ENGAGED
	seq.cancel()
	seq.abort()
	assert_true(seq.is_engaged(), "too late to stop once engaged")
	for phase: JumpSequence.Phase in [JumpSequence.Phase.STOPPING, JumpSequence.Phase.ALIGNING, JumpSequence.Phase.COUNTDOWN]:
		var early := JumpSequence.new(Vector2.UP, 3.0, SETTINGS, _stats())
		early.phase = phase
		assert_true(early.cancel(), "TR2: can cancel before the countdown ends (%d)" % phase)
