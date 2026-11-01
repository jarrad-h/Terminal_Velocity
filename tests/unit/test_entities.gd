extends TvTest
## Persistent entities (PS2–PS5, PS7): orders, travel by the player's rules,
## grudges, off-screen encounters and news.

## a — b — c in a line 150 apart (1 day at 150), d off c; gates at a and c.
func _galaxy() -> GalaxyDef:
	var raw: Dictionary = {"name": "G", "start_system": "a", "systems": [
		{"system": "a", "position": [0, 0]}, {"system": "b", "position": [150, 0]},
		{"system": "c", "position": [300, 0]}, {"system": "d", "position": [300, 150]}],
		"hyperlanes": [{"from": "a", "to": "b"}, {"from": "b", "to": "c"}, {"from": "c", "to": "d"}],
		"gate_links": [{"from": "a", "to": "c", "days": 1}]}
	return GalaxyDef.parse(DefReader.new(raw, "g.json", []))


func _def(id: String, raw: Dictionary) -> PersistentEntityDef:
	var base: Dictionary = {"name": id.capitalize(), "government": "law", "pool": "p", "start_system": "a",
		"ships": [{"ship": "cutter", "count": 2}]}
	base.merge(raw, true)
	var errors: Array[String] = []
	var def: PersistentEntityDef = PersistentEntityDef.parse(DefReader.new(base, id + ".json", errors))
	assert_true(errors.is_empty(), "entity parses: %s" % [errors])
	def.id = id
	return def


func _ctx(defs: Array, gates: bool = true, player: String = "") -> Dictionary:
	var by_id: Dictionary = {}
	for d: PersistentEntityDef in defs:
		by_id[d.id] = d
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return {"galaxy": _galaxy(), "defs": by_id, "ship_strength": {"cutter": 2.0, "brig": 5.0}, "ship_speed": {"cutter": 150.0, "brig": 75.0},
		"gate_ok": func(_def: PersistentEntityDef, _system: String) -> bool: return gates,
		"hostile": func(x: String, y: String) -> bool: return x != y,
		"exists": func(def: PersistentEntityDef) -> bool: return GateRules.is_open(def.exists_if, {}),
		"name_of": func(system_id: String) -> String: return system_id.to_upper(), "player_system": player, "rng": rng,
		"settings": {"randomness": 0.0, "loser_losses": 0.5, "loser_damage": 0.3, "winner_damage": 0.1, "floor_hull": 0.1}}


func test_routes_use_lanes_and_allowed_gates() -> void:
	var g: GalaxyDef = _galaxy()
	var with_gate: Array[Dictionary] = EntityRouting.plot(g, "a", "d", 150.0, func(_s: String) -> bool: return true)
	assert_true(with_gate.size() == 2 and with_gate[0]["via"] == "gate" and with_gate[0]["system"] == "c", "PS3: the gate is quicker (%s)" % [with_gate])
	assert_true(EntityRouting.total_days(with_gate) == 2, "1 day by gate + 1 by lane")
	var no_gate: Array[Dictionary] = EntityRouting.plot(g, "a", "d", 150.0, func(_s: String) -> bool: return false)
	assert_true(no_gate.size() == 3 and no_gate.all(func(h: Dictionary) -> bool: return h["via"] == "lane"), "refused gates: hyperlanes only")
	assert_true(EntityRouting.plot(g, "a", "a", 150.0, func(_s: String) -> bool: return true).is_empty(), "already there")


func test_hold_stays_put() -> void:
	var def: PersistentEntityDef = _def("hermit", {})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([def])
	reg.start([def], 0, ctx["rng"])
	for day: int in range(1, 10):
		reg.step_day(day, ctx)
	assert_true(reg.states["hermit"].location == "a", "PS2: hold orders keep it home")


func test_patrol_travels_hop_by_hop_and_announces() -> void:
	var def: PersistentEntityDef = _def("watch", {"orders": {"type": "patrol", "route": ["a", "c"], "stay_days": [1, 1]}})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([def], false)
	reg.start([def], 0, ctx["rng"])
	var s: EntityState = reg.states["watch"]
	assert_true(s.location == "a" and s.leave_day == 1, "starts at a, staying a day")
	reg.step_day(1, ctx)
	assert_true(s.location == "a", "still there on its last day")
	var news: Array[String] = reg.step_day(2, ctx)
	assert_true(s.in_transit() and s.transit_to == "b" and s.arrive_day == 3, "PS3: one lane hop, 1 day (%s → %s, day %d)" % [s.transit_from, s.transit_to, s.arrive_day])
	assert_true(news.size() == 1 and news[0] == "Watch departs A, due at C in 2 days", "PS7: departure announced: %s" % [news])
	assert_true(reg.step_day(3, ctx).is_empty(), "passing through b: no second announcement")
	assert_true(s.in_transit() and s.transit_to == "c", "straight on from b")
	reg.step_day(4, ctx)
	assert_true(s.location == "c" and s.leave_day == 5, "arrived at its next stop and stays")


func test_slowest_ship_sets_the_pace() -> void:
	var def: PersistentEntityDef = _def("convoy", {"ships": [{"ship": "cutter"}, {"ship": "brig"}], "orders": {"type": "travel", "destination": "b"}})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([def], false)
	reg.start([def], 0, ctx["rng"])
	var s: EntityState = reg.states["convoy"]
	reg.depart(s, def, 0, ctx)
	assert_true(s.arrive_day == 2, "TM2: the brig's 75 jump speed makes 150 units 2 days")


func test_grudge_follows_the_player_then_ends() -> void:
	var def: PersistentEntityDef = _def("ketch", {"grudge_days": 3})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([def], false, "c")
	reg.start([def], 0, ctx["rng"])
	var s: EntityState = reg.states["ketch"]
	reg.give_grudge("ketch", def, 0)
	assert_true(s.grudge_until == 3, "PS2: grudge for its data days")
	s.leave_day = 0
	reg.step_day(1, ctx)
	assert_true(s.transit_to == "b", "PS2: heads for the player's system")
	for day: int in range(2, 6):
		reg.step_day(day, ctx)
	assert_true(s.grudge_until == -1, "the grudge runs out")


func test_grudging_patrol_passes_its_stops_on_the_way() -> void:
	var def: PersistentEntityDef = _def("ketch", {"grudge_days": 9, "orders": {"type": "patrol", "route": ["a", "b"], "stay_days": [3, 3]}})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([def], false, "c")
	reg.start([def], 0, ctx["rng"])
	var s: EntityState = reg.states["ketch"]
	s.leave_day = 0
	reg.give_grudge("ketch", def, 0)
	reg.step_day(1, ctx)
	reg.step_day(2, ctx)
	assert_true(s.in_transit() and s.transit_to == "c", "PS2: with a grudge it doesn't stop at its patrol stop b on the way to the player")
	assert_true(s.transit_via == "lane", "PS4: remembers how it travels")


func test_encounters_hurt_the_loser_and_can_kill() -> void:
	var law: PersistentEntityDef = _def("law", {"ships": [{"ship": "brig", "count": 2}]})
	var outlaw: PersistentEntityDef = _def("outlaw", {"government": "outlaws"})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([law, outlaw])
	reg.start([law, outlaw], 0, ctx["rng"])
	var news: Array[String] = reg.step_day(1, ctx)
	var o: EntityState = reg.states["outlaw"]
	assert_true(o.ships.size() == 1 and is_equal_approx(o.ships[0]["hull"], 0.7), "PS5: the weaker side loses half its ships, the rest are damaged")
	assert_true(is_equal_approx(reg.states["law"].ships[0]["hull"], 0.9), "the winner takes some damage")
	assert_true(news.size() == 1 and news[0].begins_with("Law drove off Outlaw at A"), "PS5: the fight is news: %s" % [news])
	reg.step_day(2, ctx)
	assert_false(o.alive, "PS2: a second defeat finishes it")
	ctx["player_system"] = "a"
	var friend: PersistentEntityDef = _def("friend", {"government": "outlaws"})
	ctx["defs"]["friend"] = friend
	reg.states["friend"] = EntityRegistry.new_state(friend, 2, ctx["rng"])
	assert_true(reg.step_day(3, ctx).is_empty(), "PS5: no off-screen fight in the player's system")


func test_exists_condition_and_write_back() -> void:
	var ghost: PersistentEntityDef = _def("ghost", {"exists_if": "summoned", "orders": {"type": "travel", "destination": "b"}})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([ghost], false)
	reg.start([ghost], 0, ctx["rng"])
	reg.states["ghost"].leave_day = 0
	reg.step_day(1, ctx)
	assert_true(reg.states["ghost"].location == "a", "doesn't move while its condition is false")
	reg.write_back("ghost", [])
	assert_false(reg.states["ghost"].alive, "PS4: no ships left after the player's visit: gone")


func test_registry_and_news_round_trip() -> void:
	var def: PersistentEntityDef = _def("watch", {"grudge_days": 2})
	var reg := EntityRegistry.new()
	var ctx: Dictionary = _ctx([def])
	reg.start([def], 0, ctx["rng"])
	reg.give_grudge("watch", def, 4)
	var back: EntityRegistry = EntityRegistry.from_dict(JSON.parse_string(JSON.stringify(reg.to_dict())))
	assert_true(back.states["watch"].location == "a" and back.states["watch"].grudge_until == 6 and back.states["watch"].ships.size() == 2, "SV1: registry round-trips")
	var log := NewsLog.new()
	for day: int in 15:
		log.add(day, "item %d" % day)
	var recent: Array = log.recent(14, 10, 8)
	assert_true(recent.size() == 8 and recent[0]["text"] == "item 14", "PS7: newest first, capped: %s" % [recent.size()])
	assert_true(log.recent(14, 3, 8).size() == 3, "only the last N days")
	log.prune(14, 5)
	assert_true(log.items.size() == 5, "old news is dropped")
