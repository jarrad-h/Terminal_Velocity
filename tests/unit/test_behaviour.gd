extends TvTest
## A4, A5, A7: group and personality combined; weighted picks.


func test_personality_scales_odds_and_flee() -> void:
	assert_near(Behaviour.max_odds(1.5, 0.6), 0.9, "cautious takes shorter odds")
	assert_near(Behaviour.flee_threshold(25.0, -15.0), 10.0, "brave stays longer")
	assert_near(Behaviour.flee_threshold(80.0, 40.0), 100.0, "clamped to 100")
	assert_near(Behaviour.flee_threshold(10.0, -20.0), 0.0, "clamped to 0")


func test_should_flee_below_threshold() -> void:
	assert_true(Behaviour.should_flee(20.0, 100.0, 25.0), "20% < 25%")
	assert_true(not Behaviour.should_flee(30.0, 100.0, 25.0), "30% fine")
	assert_true(not Behaviour.should_flee(0.0, 0.0, 25.0), "no shields: never on this rule")


func test_role_defaults() -> void:
	assert_true(not Behaviour.fights_back("trader", "role"), "traders flee by default (A1)")
	assert_true(Behaviour.fights_back("warship", "role"), "warships fight")
	assert_true(Behaviour.fights_back("trader", "fight"), "brave trader fights back (A7)")
	assert_true(not Behaviour.fights_back("pirate", "flee"), "skittish pirate runs")
	assert_true(Behaviour.starts_fights("pirate", "role"), "pirates on sight (A3)")
	assert_true(Behaviour.starts_fights("warship", "role"), "warships on sight (A2)")
	assert_true(not Behaviour.starts_fights("trader", "role"), "traders don't start fights")
	assert_true(Behaviour.starts_fights("trader", "on_sight"), "aggressive trader does")
	assert_true(not Behaviour.starts_fights("pirate", "never"), "personality can hold back")


func test_weighted_pick() -> void:
	var w: Array[float] = [3.0, 1.0]
	assert_true(WeightedPick.pick(w, 0.0) == 0, "start")
	assert_true(WeightedPick.pick(w, 0.74) == 0, "within first 75%")
	assert_true(WeightedPick.pick(w, 0.76) == 1, "last 25%")
	assert_true(WeightedPick.pick(w, 0.9999) == 1, "end")
	var zero: Array[float] = [0.0, 0.0]
	assert_true(WeightedPick.pick(zero, 0.5) == -1, "no weight")
	var skip: Array[float] = [0.0, 2.0]
	assert_true(WeightedPick.pick(skip, 0.0) == 1, "zero weights never picked")
