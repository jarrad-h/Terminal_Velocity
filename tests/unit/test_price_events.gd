extends GutTest
## EC2: price events start, stack, apply where they should and end.


func _def(id: String, commodity: String, factor: float, chance: float, extra: Dictionary = {}) -> PriceEventDef:
	var raw: Dictionary = {"name": id, "commodity": commodity, "factor": factor, "days": [3, 3], "chance_per_day": chance}
	raw.merge(extra)
	var errors: Array[String] = []
	var d: PriceEventDef = PriceEventDef.parse(DefReader.new(raw, id + ".json", errors))
	d.id = id
	return d


func test_events_start_last_and_end() -> void:
	var rng := RandomNumberGenerator.new()
	var famine: PriceEventDef = _def("famine", "food", 1.6, 1.0, {"ports": ["forge"], "news_start": "Famine!", "news_end": "Over."})
	var events := PriceEvents.new()
	assert_eq(events.step_day([famine], 1, {}, rng), ["Famine!"] as Array[String], "EC2: a sure event starts, with news")
	assert_almost_eq(events.factor([famine], "ember", "forge", "", "food"), 1.6, 0.0001, "it applies at its port")
	assert_almost_eq(events.factor([famine], "ember", "other", "", "food"), 1.0, 0.0001, "...not elsewhere")
	assert_almost_eq(events.factor([famine], "ember", "forge", "", "water"), 1.0, 0.0001, "...nor to other goods")
	famine.chance_per_day = 0.0
	events.step_day([famine], 2, {}, rng)
	events.step_day([famine], 3, {}, rng)
	assert_true(events.active.has("famine"), "lasts its days (1-3)")
	assert_eq(events.step_day([famine], 4, {}, rng), ["Over."] as Array[String], "then ends, with news")
	assert_false(events.active.has("famine"))


func test_stacking_and_scope() -> void:
	var rng := RandomNumberGenerator.new()
	var a: PriceEventDef = _def("a", "food", 1.5, 1.0, {"governments": ["law"]})
	var b: PriceEventDef = _def("b", "food", 0.5, 1.0, {"systems": ["here"]})
	var everywhere: PriceEventDef = _def("c", "water", 2.0, 1.0)
	var events := PriceEvents.new()
	events.step_day([a, b, everywhere], 1, {}, rng)
	assert_almost_eq(events.factor([a, b, everywhere], "here", "p", "law", "food"), 0.75, 0.0001, "EC2: stacked events multiply")
	assert_almost_eq(events.factor([a, b, everywhere], "there", "p", "law", "food"), 1.5, 0.0001, "by government")
	assert_almost_eq(events.factor([a, b, everywhere], "anywhere", "p", "", "water"), 2.0, 0.0001, "no scope = everywhere")


func test_conditions_and_saving() -> void:
	var rng := RandomNumberGenerator.new()
	var gated: PriceEventDef = _def("gated", "food", 1.2, 1.0, {"condition": "war"})
	var events := PriceEvents.new()
	events.step_day([gated], 1, {}, rng)
	assert_false(events.active.has("gated"), "EC2: a flag-gated event waits for its flag")
	events.step_day([gated], 2, {"war": 1}, rng)
	assert_true(events.active.has("gated"), "...and can start once it's set")
	var back: PriceEvents = PriceEvents.from_dict(JSON.parse_string(JSON.stringify(events.to_dict())))
	assert_eq(int(back.active["gated"]), int(events.active["gated"]), "SV1: active events save and load")
