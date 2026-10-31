extends TvTest
## PS6: system memory recovers over days, scales traffic, and keeps wrecks.

const RULES: Dictionary = {"a": {"alert": {"baseline": 0.0, "recovery_per_day": 10.0},
	"pirate_presence": {"baseline": 100.0, "recovery_per_day": 15.0}}}


func test_values_move_and_clamp() -> void:
	var m := SystemMemory.new()
	assert_near(m.value("a", "alert", 0.0), 0.0, "starts at the baseline")
	m.add("a", "alert", 30.0, 0.0, 100.0)
	assert_near(m.value("a", "alert", 0.0), 30.0, "crimes raise alert")
	m.add("a", "alert", 500.0, 0.0, 100.0)
	assert_near(m.value("a", "alert", 0.0), 100.0, "capped at max")
	m.add("a", "pirate_presence", -150.0, 100.0, 200.0)
	assert_near(m.value("a", "pirate_presence", 100.0), 0.0, "never below 0")


func test_recovery_over_days() -> void:
	var m := SystemMemory.new()
	m.add("a", "alert", 25.0, 0.0, 100.0)
	m.add("a", "pirate_presence", -40.0, 100.0, 200.0)
	m.step_day(RULES)
	assert_near(m.value("a", "alert", 0.0), 15.0, "PS6: alert recovers 10 a day")
	assert_near(m.value("a", "pirate_presence", 100.0), 75.0, "presence recovers 15 a day")
	m.step_day(RULES)
	m.step_day(RULES)
	assert_near(m.value("a", "alert", 0.0), 0.0, "back to baseline, never past it")
	assert_false(m.values.get("a", {}).has("alert"), "values at baseline aren't stored")
	assert_near(SystemMemory.recover(130.0, 100.0, 15.0), 115.0, "recovers downwards too")


func test_traffic_scaling() -> void:
	assert_true(SystemMemory.scaled_count(2, 50.0, 0.0, 0.04) == 4, "PS6: high alert, more patrols")
	assert_true(SystemMemory.scaled_count(2, 50.0, 100.0, 0.02) == 1, "fewer pirates once cleared out")
	assert_true(SystemMemory.scaled_count(1, 0.0, 100.0, 0.05) == 0, "never below 0")
	assert_true(SystemMemory.scaled_count(3, 100.0, 100.0, 0.5) == 3, "at baseline: unchanged")


func test_wrecks_age_and_are_scavenged() -> void:
	var m := SystemMemory.new()
	m.set_wrecks("a", [{"ship": "pirate_raider", "days_left": 2}, {"ship": "freighter", "days_left": 1}])
	m.step_day(RULES)
	assert_true(m.wrecks_in("a").size() == 1, "PS6: a wreck is scavenged when its days run out")
	m.step_day(RULES)
	assert_true(m.wrecks_in("a").is_empty(), "all gone")


func test_round_trip() -> void:
	var m := SystemMemory.new()
	m.add("a", "alert", 20.0, 0.0, 100.0)
	m.set_wrecks("a", [{"ship": "freighter", "position": [1.0, 2.0], "days_left": 3}])
	var back: SystemMemory = SystemMemory.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_near(back.value("a", "alert", 0.0), 20.0, "values")
	assert_true(back.wrecks_in("a")[0]["ship"] == "freighter", "wrecks")
