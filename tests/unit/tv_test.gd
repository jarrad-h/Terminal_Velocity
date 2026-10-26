class_name TvTest
extends GutTest
## Shared assertions for Terminal Velocity unit tests (GUT).


func assert_near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	assert_almost_eq(actual, expected, tolerance, message)


func assert_vec_near(actual: Vector2, expected: Vector2, message: String, tolerance: float = 0.001) -> void:
	assert_true(actual.distance_to(expected) <= tolerance, "%s: expected %s, got %s" % [message, expected, actual])
