class_name TestCase
extends RefCounted
## Base class for tests run by tests/run_tests.gd.

var failed: bool = false
var messages: Array[String] = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		messages.append(message)


func assert_near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	assert_true(absf(actual - expected) <= tolerance, "%s: expected %f, got %f" % [message, expected, actual])


func assert_vec_near(actual: Vector2, expected: Vector2, message: String, tolerance: float = 0.001) -> void:
	assert_true(actual.distance_to(expected) <= tolerance, "%s: expected %s, got %s" % [message, expected, actual])
