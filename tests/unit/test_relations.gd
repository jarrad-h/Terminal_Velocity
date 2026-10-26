extends TvTest
## G1–G3, A5, A8.


func _gov(id: String, allies: Array[String] = [], enemies: Array[String] = [], threshold: float = -50.0) -> GovernmentDef:
	var g := GovernmentDef.new()
	g.id = id
	g.allies = allies
	g.enemies = enemies
	g.crime_threshold = threshold
	g.penalties = {"shoot": 3.0, "disable": 10.0, "board": 20.0, "kill": 30.0}
	return g


func test_enemies_are_hostile_either_way() -> void:
	var law := _gov("law", [], ["pirates"])
	var pirates := _gov("pirates")
	assert_true(Relations.governments_hostile(law, pirates), "law lists pirates")
	assert_true(Relations.governments_hostile(pirates, law), "symmetric even if only one side lists it")


func test_allies_and_strangers_are_not_hostile() -> void:
	var law := _gov("law", ["traders"], ["pirates"])
	var traders := _gov("traders", ["law"])
	assert_true(not Relations.governments_hostile(law, traders), "allies")
	assert_true(not Relations.governments_hostile(law, _gov("miners")), "unrelated")
	assert_true(not Relations.governments_hostile(law, law), "own government")
	assert_true(not Relations.governments_hostile(law, null), "no government")


func test_allied_includes_own_government() -> void:
	var law := _gov("law", ["traders"])
	assert_true(Relations.allied(law, law), "same government")
	assert_true(Relations.allied(law, _gov("traders")), "listed ally")
	assert_true(Relations.allied(_gov("traders"), law), "ally listed by the other side")
	assert_true(not Relations.allied(law, _gov("pirates")), "not an ally")
	assert_true(not Relations.allied(law, null), "player has no government")


func test_record_below_threshold_is_hostile() -> void:
	var law := _gov("law", [], [], -50.0)
	assert_true(not Relations.hostile_to_player(law, -49.0, false), "above threshold")
	assert_true(Relations.hostile_to_player(law, -51.0, false), "below threshold (G3)")


func test_pirates_high_threshold_means_hostile_from_the_start() -> void:
	assert_true(Relations.hostile_to_player(_gov("pirates", [], [], 1000.0), 0.0, false), "record 0 < 1000 (A3)")


func test_provoked_overrides_good_record() -> void:
	assert_true(Relations.hostile_to_player(_gov("law"), 500.0, true), "A8 provoked")


func test_penalties_by_act() -> void:
	var law := _gov("law")
	assert_near(Relations.after_penalty(0.0, law, "shoot"), -3.0, "shoot")
	assert_near(Relations.after_penalty(-3.0, law, "kill"), -33.0, "kill")
	assert_near(Relations.after_penalty(5.0, null, "kill"), 5.0, "no government, no change")


func test_odds() -> void:
	assert_true(Relations.odds_ok(10.0, 15.0, 1.5), "1.5x enemy within 1.5 odds")
	assert_true(not Relations.odds_ok(10.0, 16.0, 1.5), "beyond odds")
	assert_true(Relations.odds_ok(10.0, 0.0, 0.5), "no enemies always ok")
	assert_true(not Relations.odds_ok(0.0, 5.0, 10.0), "no strength of our own")


func test_friendly_fire_scale() -> void:
	var law := _gov("law", ["traders"], ["pirates"])
	assert_near(Relations.damage_scale(false, law, _gov("traders"), 25.0), 0.25, "AI hitting an ally: 25% (C11)")
	assert_near(Relations.damage_scale(false, law, law, 0.0), 0.0, "own government, friendly fire off")
	assert_near(Relations.damage_scale(false, law, _gov("pirates"), 0.0), 1.0, "enemies always full damage")
	assert_near(Relations.damage_scale(true, null, law, 0.0), 1.0, "player shots always full damage")
	assert_near(Relations.damage_scale(false, law, null, 0.0), 1.0, "targets with no government (dummy, scenery)")
