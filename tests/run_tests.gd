extends SceneTree
## Minimal test runner. Run with:
##   godot --headless --path . --script res://tests/run_tests.gd
## Each test file extends TestCase; every method starting with `test_` runs.

const TEST_FILES: Array[String] = [
	"res://tests/test_flight_model.gd",
]


func _initialize() -> void:
	var failures: int = 0
	var count: int = 0
	for path: String in TEST_FILES:
		var script: GDScript = load(path)
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.call(name)
			count += 1
			if case.failed:
				failures += 1
				print("FAIL %s::%s\n  %s" % [path.get_file(), name, "\n  ".join(case.messages)])
	print("%d tests, %d failed" % [count, failures])
	quit(1 if failures > 0 else 0)
