extends TvTest
## C2–C3: intercept, turret arc and homing.


func test_stationary_target_aims_straight() -> void:
	var dir: Vector2 = Aim.intercept_direction(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 500.0)
	assert_vec_near(dir, Vector2(1, 0), "direct")


func test_moving_target_is_led_and_shot_meets_it() -> void:
	var target := Vector2(400, 0)
	var vel := Vector2(0, 100)
	var dir: Vector2 = Aim.intercept_direction(Vector2.ZERO, target, vel, 500.0)
	assert_true(dir.y > 0.0, "aims ahead of the target's motion")
	# Simulate: find the time the shot reaches the target's distance and compare.
	var t: float = 0.0
	var best: float = INF
	while t < 2.0:
		best = minf(best, (dir * 500.0 * t).distance_to(target + vel * t))
		t += 0.001
	assert_true(best < 1.0, "shot meets the target (closest %f px)" % best)


func test_unreachable_target_falls_back_to_direct() -> void:
	var dir: Vector2 = Aim.intercept_direction(Vector2.ZERO, Vector2(100, 0), Vector2(1000, 0), 100.0)
	assert_vec_near(dir, Vector2(1, 0), "faster target: aim straight")


func test_turret_arc() -> void:
	# Heading up (rotation 0). 90° arc covers 45° either side.
	assert_true(Aim.within_arc(0.0, Vector2(0, -1), 90.0), "straight ahead in arc")
	assert_true(Aim.within_arc(0.0, Vector2(1, -1.2), 90.0), "slightly right in arc")
	assert_true(not Aim.within_arc(0.0, Vector2(1, 0), 90.0), "right angle outside 90° arc")
	assert_true(Aim.within_arc(0.0, Vector2(0, 1), 360.0), "full arc covers behind")


func test_homing_turns_at_fixed_rate_without_overshoot() -> void:
	var r: float = Aim.homing_rotation(0.0, Vector2.ZERO, Vector2(100, 0), 90.0, 0.5)
	assert_near(r, PI / 4.0, "45° in 0.5 s at 90°/s")
	var aligned: float = Aim.homing_rotation(PI / 2.0 - 0.01, Vector2.ZERO, Vector2(100, 0), 90.0, 1.0)
	assert_near(aligned, PI / 2.0, "stops on target bearing")
