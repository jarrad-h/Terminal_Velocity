extends TvTest
## V3: weapon/hardpoint fit, pivot and turret barrel aiming; V2: capsule gaps.

const LASER: Array[String] = ["fixed", "pivot", "turret"]


func test_fit_needs_matching_size_and_mount() -> void:
	assert_true(MountFit.fits("small", LASER, "turret", "small", "turret"), "small turret laser on a small turret")
	assert_true(not MountFit.fits("small", LASER, "turret", "medium", "turret"), "size must match")
	assert_true(not MountFit.fits("small", LASER, "fixed", "small", "turret"), "item mount must match the hardpoint")
	assert_true(not MountFit.fits("small", ["launcher"] as Array[String], "turret", "small", "turret"), "weapon must come in that mount")
	assert_string_contains(MountFit.problem("large", LASER, "pivot", "small", "pivot"), "large weapon")


func test_relative_angle() -> void:
	# Ship facing up: a target to starboard (+x) is +90°.
	assert_near(MountAim.relative_angle(0.0, Vector2.RIGHT), PI / 2.0, "starboard")
	assert_near(MountAim.relative_angle(PI / 2.0, Vector2.RIGHT), 0.0, "ship facing right: dead ahead")


func test_pivot_clamps_to_its_arc() -> void:
	# 30° total pivot: ±15°.
	assert_near(MountAim.clamp_to_arc(deg_to_rad(40.0), 30.0), deg_to_rad(15.0), "held at the arc edge")
	assert_near(MountAim.clamp_to_arc(deg_to_rad(-10.0), 30.0), deg_to_rad(-10.0), "inside the arc")
	assert_true(MountAim.in_arc(deg_to_rad(15.0), 30.0) and not MountAim.in_arc(deg_to_rad(16.0), 30.0), "in_arc")
	assert_true(MountAim.in_arc(PI, 360.0), "full turret covers everything")


func test_barrel_turns_at_traverse_rate() -> void:
	var angle: float = MountAim.step(0.0, PI / 2.0, 90.0, 360.0, 0.5)
	assert_near(angle, deg_to_rad(45.0), "90°/s for half a second")
	angle = MountAim.step(angle, PI / 2.0, 90.0, 360.0, 1.0)
	assert_near(angle, PI / 2.0, "stops on the aim point")


func test_full_turret_takes_the_short_way_round() -> void:
	var angle: float = MountAim.step(deg_to_rad(170.0), deg_to_rad(-170.0), 10.0, 360.0, 1.0)
	assert_near(absf(angle), PI, "crosses the stern rather than swinging 340°")


func test_limited_arc_never_swings_through_the_back() -> void:
	var angle: float = MountAim.step(deg_to_rad(100.0), deg_to_rad(-100.0), 1000.0, 270.0, 0.01)
	assert_true(angle < deg_to_rad(100.0) and angle > 0.0, "moves back toward the nose: %f" % rad_to_deg(angle))


func test_capsule_gap_alongside_and_end_on() -> void:
	var size := Vector2(40, 120)
	# Side by side, 100 px apart centre to centre: edges 60 px apart.
	assert_near(Capsule.gap(Vector2.ZERO, 0.0, size, Vector2.ZERO, Vector2(100, 0), 0.0, size, Vector2.ZERO), 60.0, "alongside")
	# Nose to tail, 200 px apart: 200 - 60 - 60 = 80.
	assert_near(Capsule.gap(Vector2.ZERO, 0.0, size, Vector2.ZERO, Vector2(0, 200), 0.0, size, Vector2.ZERO), 80.0, "end on")
	# The offset moves the hull: shifted 14 px toward the other ship.
	assert_near(Capsule.gap(Vector2.ZERO, 0.0, size, Vector2(14, 0), Vector2(100, 0), 0.0, size, Vector2.ZERO), 46.0, "offset hull")
