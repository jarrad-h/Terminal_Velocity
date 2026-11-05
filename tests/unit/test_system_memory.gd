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


func test_danger_counts_levels_and_recovery() -> void:
	# EC9: traders thin and patrols gather with danger, both capped; levels; proportional recovery.
	var cfg: Dictionary = {"trader_cut_per_point": 0.005, "trader_cut_max": 0.5, "patrol_per_point": 0.03, "patrol_max_extra": 2}
	assert_eq(SystemMemory.danger_count(4, "trader", 5.0, 5.0, cfg), 4, "at its normal level: no change")
	assert_eq(SystemMemory.danger_count(4, "trader", 45.0, 5.0, cfg), 3, "danger thins traders")
	assert_eq(SystemMemory.danger_count(4, "trader", 100.0, 0.0, cfg), 2, "...by at most half")
	assert_eq(SystemMemory.danger_count(2, "warship", 40.0, 5.0, cfg), 3, "danger draws patrols")
	assert_eq(SystemMemory.danger_count(2, "warship", 100.0, 0.0, cfg), 4, "...at most two more")
	assert_eq(SystemMemory.danger_count(1, "pirate", 100.0, 0.0, cfg), 1, "pirates aren't counted by danger")
	var levels: Array = [20.0, 45.0, 70.0]
	assert_eq(SystemMemory.danger_level(5.0, levels), "low")
	assert_eq(SystemMemory.danger_level(20.0, levels), "medium")
	assert_eq(SystemMemory.danger_level(50.0, levels), "high")
	assert_eq(SystemMemory.danger_level(90.0, levels), "extreme")
	var m := SystemMemory.new()
	m.add("a", "danger", 55.0, 5.0, 100.0)
	m.step_day({"a": {"danger": {"baseline": 5.0, "recovery_per_day": 0.0, "recovery_fraction": 0.15}}})
	assert_almost_eq(m.value("a", "danger", 5.0), 51.75, 0.01, "60 recovers 15% of its 55 gap a day")
