extends TvTest
## A8: grievance builds with damage, drains over time, and only passing the
## tolerance turns a ship hostile.


func test_single_accidental_hit_is_forgiven() -> void:
	# 10 damage to a 300-total ship = 3.3%, well under a 20% tolerance.
	var g: float = Grievance.add(0.0, 10.0, 300.0)
	assert_near(g, 10.0 / 3.0, "share of total health")
	assert_true(not Grievance.exceeded(g, 20.0), "one stray shot doesn't turn it hostile")


func test_sustained_fire_crosses_tolerance() -> void:
	var g: float = 0.0
	for i: int in 7:
		g = Grievance.add(g, 10.0, 300.0)
	assert_true(Grievance.exceeded(g, 20.0), "70 of 300 = 23% > 20%")


func test_forgiveness_drains_over_time() -> void:
	assert_near(Grievance.decay(15.0, 4.0, 2.0), 7.0, "4%/s for 2 s")
	assert_near(Grievance.decay(3.0, 4.0, 2.0), 0.0, "never below zero")


func test_personality_shades_tolerance() -> void:
	assert_near(Grievance.tolerance(20.0, 0.5), 10.0, "hot-headed snaps sooner")
	assert_near(Grievance.tolerance(20.0, 1.5), 30.0, "patient pilot later")


func test_no_health_means_any_damage_counts() -> void:
	assert_true(Grievance.exceeded(Grievance.add(0.0, 1.0, 0.0), 1000.0), "no health to share")
