extends TvTest
## S2, G4, C9, C10.


func _obj(id: String, pos: Vector2, landable: bool = true, gov: String = "", min_record: float = -1000.0) -> SystemObjectDef:
	var o := SystemObjectDef.new()
	o.id = id
	o.position = pos
	o.landable = landable
	o.government = gov
	o.min_record = min_record
	return o


func test_landing_check() -> void:
	assert_true(PortRules.landing_check(50.0, 100.0, 0.6, 30.0, 60.0) == "", "inside and slow (S2)")
	assert_true(PortRules.landing_check(70.0, 100.0, 0.6, 30.0, 60.0) == "far", "outside the landing radius")
	assert_true(PortRules.landing_check(50.0, 100.0, 0.6, 90.0, 60.0) == "fast", "too fast")


func test_landing_allowed_by_record() -> void:
	assert_true(PortRules.landing_allowed("law", -20.0, -20.0), "at the minimum (G4)")
	assert_true(not PortRules.landing_allowed("law", -21.0, -20.0), "below it: refused")
	assert_true(PortRules.landing_allowed("", -999.0, 0.0), "no government always accepts")


func test_boarding_check() -> void:
	assert_true(PortRules.boarding_check(40.0, 60.0, 20.0, 40.0) == "", "alongside and matched (C9)")
	assert_true(PortRules.boarding_check(80.0, 60.0, 20.0, 40.0) == "far", "too far")
	assert_true(PortRules.boarding_check(40.0, 60.0, 50.0, 40.0) == "fast", "moving too fast relative to it")


func test_board_credits_scale_with_wealth() -> void:
	assert_true(PortRules.board_credits(Vector2(2000, 6000), 1.0, 0.5) == 4000, "trader freighter mid-roll")
	assert_true(PortRules.board_credits(Vector2(2000, 6000), 0.1, 0.5) == 400, "patrol: a tenth")
	assert_true(PortRules.board_credits(Vector2(0, 0), 1.0, 0.9) == 0, "nothing aboard")


func test_board_options_lock_out() -> void:
	assert_true(PortRules.board_options(false) == ["take", "assist", "scuttle", "leave"], "first boarding: everything")
	assert_true(PortRules.board_options(true) == ["scuttle", "leave"], "after taking credits: no assist")
	assert_true(PortRules.board_options(false, true) == ["take", "scuttle", "leave"], "assisted once: no second assist")


func test_rescue_fee() -> void:
	assert_true(PortRules.rescue_fee(1200, 10.0) == 120, "10%")
	assert_true(PortRules.rescue_fee(-50, 10.0) == 0, "never negative")


func test_rescue_port_prefers_accepting_nearest() -> void:
	var objects: Array[SystemObjectDef] = [
		_obj("near_refuses", Vector2(100, 0), true, "law", 0.0),
		_obj("far_accepts", Vector2(1000, 0), true, "traders", -100.0),
		_obj("gas_giant", Vector2(50, 0), false),
	]
	var records: Dictionary = {"law": -50.0}
	assert_true(PortRules.rescue_port(objects, Vector2.ZERO, records, 0.0) == 1, "skips the refusing port and the gas giant")
	records["law"] = 10.0
	assert_true(PortRules.rescue_port(objects, Vector2.ZERO, records, 0.0) == 0, "nearest when it accepts")
	var nobody: Array[SystemObjectDef] = [_obj("a", Vector2(10, 0), true, "law", 100.0)]
	assert_true(PortRules.rescue_port(nobody, Vector2.ZERO, {}, 0.0) == -1, "C10: a port that refuses never takes the player in")
	var none: Array[SystemObjectDef] = [_obj("rock", Vector2(10, 0), false)]
	assert_true(PortRules.rescue_port(none, Vector2.ZERO, {}, 0.0) == -1, "no ports at all")


func test_repair_cost() -> void:
	assert_true(PortRules.repair_cost(150.0, 0.0) == 0, "free by default (S3)")
	assert_true(PortRules.repair_cost(150.0, 2.0) == 300, "per point")
	assert_true(PortRules.repair_cost(-5.0, 2.0) == 0, "nothing missing")


func test_refuel_buys_what_you_can_afford() -> void:
	var full: Dictionary = PortRules.refuel(100.0, 300.0, 2.0, 1000)
	assert_near(full["units"], 200.0, "TR8: fills the tank")
	assert_true(full["cost"] == 400, "at the price per unit")
	var part: Dictionary = PortRules.refuel(100.0, 300.0, 2.0, 151)
	assert_near(part["units"], 75.0, "as much as the credits pay for")
	assert_true(part["cost"] == 150, "never more than you have")
	assert_near(PortRules.refuel(300.0, 300.0, 2.0, 1000)["units"], 0.0, "already full")
	assert_true(PortRules.refuel(0.0, 300.0, 0.0, 0)["cost"] == 0, "free fuel")
	assert_near(PortRules.refuel(0.0, 300.0, 2.0, 0)["units"], 0.0, "no credits, no fuel")


func test_nearest_haven_by_travel_days() -> void:
	# C10: a — b — c in a line 100 apart, d off b at 250 (slow), h hidden off a.
	var raw: Dictionary = {"name": "G", "start_system": "a", "systems": [
		{"system": "a", "position": [0, 0]}, {"system": "b", "position": [100, 0]},
		{"system": "c", "position": [200, 0]}, {"system": "d", "position": [100, 250]},
		{"system": "h", "position": [0, -100], "map_state": "hidden"}],
		"hyperlanes": [{"from": "a", "to": "b"}, {"from": "b", "to": "c"}, {"from": "b", "to": "d"}, {"from": "h", "to": "a"}]}
	var errors: Array[String] = []
	var g: GalaxyDef = GalaxyDef.parse(DefReader.new(raw, "g.json", errors))
	assert_true(errors.is_empty(), "galaxy parses")
	assert_eq(PortRules.nearest_haven(g, "a", {"a": true, "c": true}, 100.0)["system"], "a", "here when here accepts")
	var far: Dictionary = PortRules.nearest_haven(g, "a", {"c": true, "d": true}, 100.0)
	assert_true(far["system"] == "c" and int(far["days"]) == 2, "the nearest by days (c: 2 days; d: 4)")
	assert_eq(PortRules.nearest_haven(g, "b", {"h": true}, 100.0)["system"], "h", "rescuers use hidden lanes too")
	assert_eq(PortRules.nearest_haven(g, "a", {}, 100.0)["system"], "", "nowhere accepts")
	# Secret or locked systems are never a destination or stopover.
	assert_eq(PortRules.nearest_haven(g, "a", {"c": true, "d": true}, 100.0, {"c": true})["system"], "d", "a closed system isn't a destination")
	assert_eq(PortRules.nearest_haven(g, "a", {"c": true}, 100.0, {"b": true})["system"], "", "...nor a stopover")
	assert_eq(PortRules.nearest_haven(g, "b", {"c": true}, 100.0, {"b": true})["system"], "c", "dying in a closed system, the rescuer still sets off from it")
	assert_true(PortRules.nearest_haven(g, "b", {"h": true}, 100.0)["route"] == ["a", "h"], "the route comes back for revealing")
	raw["hyperlanes"][3]["rescue_reveals"] = false
	var g2: GalaxyDef = GalaxyDef.parse(DefReader.new(raw, "g.json", errors))
	assert_true(not g2.lane_reveals("a", "h") and g2.lane_reveals("a", "b"), "a lane can keep its far end hidden")
