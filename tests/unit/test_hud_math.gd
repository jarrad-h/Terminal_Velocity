extends TvTest
## H3: schematic colour and fit.


func test_health_colour_blends_full_half_empty() -> void:
	var full := Color.GREEN
	var half := Color.YELLOW
	var empty := Color.RED
	assert_true(HudMath.health_colour(1.0, full, half, empty).is_equal_approx(full), "full")
	assert_true(HudMath.health_colour(0.5, full, half, empty).is_equal_approx(half), "half")
	assert_true(HudMath.health_colour(0.0, full, half, empty).is_equal_approx(empty), "empty")
	assert_true(HudMath.health_colour(0.25, full, half, empty).is_equal_approx(empty.lerp(half, 0.5)), "between")
	assert_true(HudMath.health_colour(2.0, full, half, empty).is_equal_approx(full), "clamped")


func test_fit_scale() -> void:
	assert_near(HudMath.fit_scale(Vector2(50, 200), Vector2(100, 100), 4.0), 0.5, "length limits")
	assert_near(HudMath.fit_scale(Vector2(10, 10), Vector2(100, 100), 2.0), 2.0, "capped")
