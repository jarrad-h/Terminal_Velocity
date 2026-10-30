extends TvTest
## Gates (TR5, TR6): open conditions, docking and travel checks.


func test_open_conditions_read_flags() -> void:
	assert_true(GateRules.is_open("", {}), "no condition: always open")
	assert_true(GateRules.is_open("!closed_x", {}), "open while the flag isn't set")
	assert_false(GateRules.is_open("!closed_x", {"closed_x": 1}), "TR6: a flag closes it")
	assert_true(GateRules.is_open("powered", {"powered": 2}), "open while set")
	assert_false(GateRules.is_open("powered", {}), "closed until set")


func test_condition_names() -> void:
	assert_true(GateRules.is_valid_condition("!graveyard_gate_closed"), "negated name")
	assert_true(GateRules.is_valid_condition(""), "empty")
	assert_false(GateRules.is_valid_condition("!"), "no name")
	assert_false(GateRules.is_valid_condition("Gate Closed"), "not snake_case")


func test_docking() -> void:
	assert_true(GateRules.dock_problem(false, 50.0, 0.0) == GateRules.CLOSED, "closed gate refuses")
	assert_true(GateRules.dock_problem(true, 10.0, 15.0) == GateRules.RECORD, "TR6: record below the minimum")
	assert_true(GateRules.dock_problem(true, 15.0, 15.0) == "", "at the minimum is fine")


func test_travel() -> void:
	assert_true(GateRules.travel_problem(false, 1000, 50) == GateRules.CLOSED, "closed destination")
	assert_true(GateRules.travel_problem(true, 49, 50) == GateRules.CREDITS, "TR6: can't pay the fee")
	assert_true(GateRules.travel_problem(true, 50, 50) == "", "exactly enough")
