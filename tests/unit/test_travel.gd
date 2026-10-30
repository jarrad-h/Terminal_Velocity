extends TvTest
## Hyperlane travel (TR1–TR4, TR7, TR8, TM2), the calendar and day clock
## (TM1, TM3) and the serialisable travel state.

## a — b — c in a line 100 apart, d off b at 250 (a slow lane), e linked to c
## and d; h hidden off a.
func _galaxy() -> GalaxyDef:
	var raw: Dictionary = {"name": "G", "start_system": "a", "systems": [
		{"system": "a", "position": [0, 0], "map_state": "explored"},
		{"system": "b", "position": [100, 0]},
		{"system": "c", "position": [200, 0]},
		{"system": "d", "position": [100, 250]},
		{"system": "e", "position": [200, 250]},
		{"system": "h", "position": [0, -100], "map_state": "hidden"}],
		"hyperlanes": [{"from": "a", "to": "b"}, {"from": "b", "to": "c"}, {"from": "b", "to": "d"},
			{"from": "c", "to": "e"}, {"from": "d", "to": "e"}, {"from": "h", "to": "a"}]}
	var errors: Array[String] = []
	var galaxy: GalaxyDef = GalaxyDef.parse(DefReader.new(raw, "g.json", errors))
	assert_true(errors.is_empty(), "test galaxy parses: %s" % [errors])
	return galaxy


func _hidden() -> Dictionary:
	return TravelState.new().hidden_set(_galaxy())


func test_neighbours_follow_lanes_both_ways() -> void:
	var g: GalaxyDef = _galaxy()
	assert_true(Hyperlanes.neighbours(g, "b") == ["a", "c", "d"], "b's neighbours")
	assert_true(Hyperlanes.neighbours(g, "a") == ["b", "h"], "lanes are two-way")
	assert_true(Hyperlanes.are_adjacent(g, "c", "b"), "adjacent")
	assert_false(Hyperlanes.are_adjacent(g, "a", "c"), "TR1: distant systems take several jumps")


func test_hidden_systems_and_their_lanes_are_left_out() -> void:
	var g: GalaxyDef = _galaxy()
	assert_true(Hyperlanes.neighbours(g, "a", _hidden()) == ["b"], "TR7: hidden lane not offered")
	assert_true(Hyperlanes.plot_route(g, "b", "h", 150.0, _hidden()).is_empty(), "hidden system not routable")
	assert_true(Hyperlanes.plot_route(g, "b", "h", 150.0) == ["a", "h"], "routable once revealed")


func test_jump_days_round_up_and_are_at_least_one() -> void:
	assert_true(Hyperlanes.jump_days(100.0, 150.0) == 1, "short lane: 1 day")
	assert_true(Hyperlanes.jump_days(150.0, 150.0) == 1, "exactly one day's travel")
	assert_true(Hyperlanes.jump_days(151.0, 150.0) == 2, "rounds up")
	assert_true(Hyperlanes.jump_days(0.0, 150.0) == 1, "at least 1 day")
	assert_true(Hyperlanes.jump_days(250.0, 100.0) == 3, "slow ship, long lane")


func test_fuel_is_flat_per_jump() -> void:
	assert_near(Hyperlanes.jump_fuel(100.0, 10.0), 100.0, "TR8: short lane")
	assert_near(Hyperlanes.jump_fuel(100.0, 900.0), 100.0, "TR8: long lane costs the same")


func test_route_takes_fewest_days() -> void:
	var g: GalaxyDef = _galaxy()
	assert_true(Hyperlanes.plot_route(g, "a", "c", 150.0) == ["b", "c"], "two jumps")
	assert_true(Hyperlanes.plot_route(g, "a", "a", 150.0).is_empty(), "already there")
	var route: Array[String] = Hyperlanes.plot_route(g, "a", "e", 150.0)
	assert_true(route.size() == 3 and route[0] == "b" and route[2] == "e", "a→e in three jumps: %s" % [route])
	var cost: Dictionary = Hyperlanes.route_cost(g, "a", route, 150.0, 100.0)
	assert_true(cost["days"] == 4 and cost["jumps"] == 3, "route days and jumps: %s" % [cost])
	assert_near(cost["fuel"], 300.0, "route fuel")


func test_direct_lane_wins_a_tie_on_days() -> void:
	var raw: Dictionary = {"name": "G", "start_system": "a", "systems": [
		{"system": "a", "position": [0, 0]}, {"system": "m", "position": [100, 0]}, {"system": "z", "position": [200, 0]}],
		"hyperlanes": [{"from": "a", "to": "m"}, {"from": "m", "to": "z"}, {"from": "a", "to": "z"}]}
	var g: GalaxyDef = GalaxyDef.parse(DefReader.new(raw, "g.json", []))
	assert_true(Hyperlanes.plot_route(g, "a", "z", 100.0) == ["z"], "2 days either way; fewer jumps wins")
	assert_true(Hyperlanes.plot_route(g, "a", "z", 150.0) == ["z"], "direct 2 days beats 1 + 1 on jumps")


func test_jump_problems_in_order() -> void:
	assert_true(Hyperlanes.jump_problem("", true, 9000.0, 8000.0, 300.0, 100.0) == Hyperlanes.NO_DESTINATION, "pick a destination first")
	assert_true(Hyperlanes.jump_problem("b", false, 9000.0, 8000.0, 300.0, 100.0) == Hyperlanes.NOT_ADJACENT, "adjacent only")
	assert_true(Hyperlanes.jump_problem("b", true, 7000.0, 8000.0, 300.0, 100.0) == Hyperlanes.INSIDE, "TR2: beyond the jump radius")
	assert_true(Hyperlanes.jump_problem("b", true, 9000.0, 8000.0, 50.0, 100.0) == Hyperlanes.NO_FUEL, "TR2: enough fuel")
	assert_true(Hyperlanes.jump_problem("b", true, 8000.0, 8000.0, 100.0, 100.0) == "", "exactly at the radius with exactly enough fuel")


func test_arrival_faces_inward_from_the_origin_side() -> void:
	var g: GalaxyDef = _galaxy()
	var b: Vector2 = Hyperlanes.bearing(g, "a", "b")
	assert_vec_near(b, Vector2.RIGHT, "a→b points right on the map")
	var s: FlightState = Hyperlanes.arrival(b, 8000.0, 130.0)
	assert_vec_near(s.position, Vector2(-8000, 0), "TR4: arrives on the side facing the origin")
	assert_vec_near(s.velocity, Vector2(130, 0), "TR4: moving inward along the bearing at reduced speed")
	assert_vec_near(FlightModel.heading(s.rotation), Vector2.RIGHT, "facing the direction of travel")


func test_calendar_dates() -> void:
	assert_true(Calendar.date_text("3200-01-01", 0) == "1 Jan 3200", "day 0 is the start date")
	assert_true(Calendar.date_text("3200-01-01", 31) == "1 Feb 3200", "31 days later")
	assert_true(Calendar.date_text("3200-02-28", 1) == "29 Feb 3200", "3200 is a leap year")
	assert_true(Calendar.date_text("3200-12-31", 1) == "1 Jan 3201", "rolls the year")
	assert_true(Calendar.is_valid_date("3200-02-29"), "leap day valid")
	assert_false(Calendar.is_valid_date("3100-02-29"), "3100 is not a leap year")
	assert_false(Calendar.is_valid_date("3200-13-01"), "no month 13")
	assert_false(Calendar.is_valid_date("1 Jan 3200"), "wrong format")


func test_day_clock_steps_one_day_at_a_time() -> void:
	var clock := DayClock.new()
	var seen: Array[int] = []
	clock.day_passed.connect(func(day: int) -> void: seen.append(day))
	clock.advance(3)
	clock.advance(0)
	clock.advance(-2)
	assert_true(clock.day == 3, "TM1: three days passed")
	assert_true(seen == [1, 2, 3], "TM3: each day stepped in order: %s" % [seen])


func test_map_states_explore_and_reveal() -> void:
	var g: GalaxyDef = _galaxy()
	var t := TravelState.new()
	assert_true(t.map_state(g, "a") == "explored", "start state from data")
	assert_true(t.map_state(g, "b") == "unexplored", "default start state")
	assert_true(t.map_state(g, "h") == "hidden", "hidden from data")
	t.mark_explored("b")
	assert_true(t.map_state(g, "b") == "explored", "visiting explores")
	assert_false(t.reveal(g, "b"), "reveal only affects hidden systems")
	assert_true(t.reveal(g, "h"), "reveal a hidden system")
	assert_true(t.map_state(g, "h") == "unexplored", "TR7: revealed systems are unexplored until visited")
	assert_true(t.hidden_set(g).is_empty(), "nothing hidden now")


func test_travel_state_round_trips() -> void:
	var t := TravelState.new()
	t.current_system = "b"
	t.fuel = 150.0
	t.route.assign(["c", "e"])
	t.map_changes = {"b": "explored", "h": "unexplored"}
	var back: TravelState = TravelState.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	assert_true(back.current_system == "b" and back.destination() == "c", "system and destination")
	assert_near(back.fuel, 150.0, "fuel")
	assert_true(back.route == ["c", "e"], "route")
	assert_true(back.map_changes == {"b": "explored", "h": "unexplored"}, "map changes")


func test_map_fits_points_inside_the_rect() -> void:
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(200, 100)]
	var t: Transform2D = MapLayout.fit(points, Rect2(0, 0, 420, 420), 10.0)
	assert_vec_near(t * Vector2(0, 0), Vector2(10, 110), "left edge at the margin, centred vertically")
	assert_vec_near(t * Vector2(200, 100), Vector2(410, 310), "keeps the aspect ratio")
	var single: Transform2D = MapLayout.fit([Vector2(5, 5)] as Array[Vector2], Rect2(0, 0, 100, 100), 10.0)
	assert_vec_near(single * Vector2(5, 5), Vector2(50, 50), "one system sits in the middle")


func test_map_pick_nearest_within_radius() -> void:
	var points: Array[Vector2] = [Vector2(0, 0), Vector2(30, 0)]
	assert_true(MapLayout.pick(points, Vector2(20, 2), 14.0) == 1, "nearest")
	assert_true(MapLayout.pick(points, Vector2(15, 40), 14.0) == -1, "nothing close enough")
