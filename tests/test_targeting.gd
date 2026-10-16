extends TestCase
## C8: nearest and cycle.

var _points: Array[Vector2] = [Vector2(300, 0), Vector2(100, 0), Vector2(0, 200)]


func test_nearest() -> void:
	assert_true(Targeting.nearest(Vector2.ZERO, _points) == 1, "closest is index 1")
	var empty: Array[Vector2] = []
	assert_true(Targeting.nearest(Vector2.ZERO, empty) == -1, "none")


func test_cycle_goes_nearest_first_and_wraps() -> void:
	var a: int = Targeting.cycle(Vector2.ZERO, _points, -1)
	var b: int = Targeting.cycle(Vector2.ZERO, _points, a)
	var c: int = Targeting.cycle(Vector2.ZERO, _points, b)
	var d: int = Targeting.cycle(Vector2.ZERO, _points, c)
	assert_true([a, b, c] == [1, 2, 0], "order by distance, got %s" % [[a, b, c]])
	assert_true(d == 1, "wraps to nearest")


func test_cycle_unknown_current_picks_nearest() -> void:
	assert_true(Targeting.cycle(Vector2.ZERO, _points, 7) == 1, "stale index -> nearest")
