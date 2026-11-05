extends GutTest
## EC1, EC3, EC5: prices, saturation and the cargo hold.

const ECONOMY: Dictionary = {"tiers": {"low": 0.7, "medium": 1.0, "high": 1.3}, "sell_spread_pct": 5.0,
	"saturation": {"pct_per_10_units": 2.0, "cap_pct": 30.0, "recovery_per_day": 0.2}}


func test_prices_by_tier_saturation_and_events() -> void:
	assert_eq(Market.buy_price(100.0, "low", 0.0, 1.0, ECONOMY), 70, "EC1: low tier")
	assert_eq(Market.buy_price(100.0, "high", 0.0, 1.0, ECONOMY), 130, "high tier")
	assert_eq(Market.buy_price(100.0, "medium", 0.1, 1.0, ECONOMY), 110, "EC5: saturation raises it")
	assert_eq(Market.buy_price(100.0, "medium", 0.0, 1.6, ECONOMY), 160, "EC2: an event multiplies it")
	assert_eq(Market.buy_price(1.0, "low", -0.3, 0.1, ECONOMY), 1, "never below 1")
	assert_eq(Market.sell_price(100, ECONOMY), 95, "EC1: the player sells 5% under the buy price")


func test_saturation_moves_caps_and_recovers() -> void:
	assert_almost_eq(Market.after_trade(0.0, 10, ECONOMY), 0.02, 0.0001, "EC5: buying 10 raises it 2%")
	assert_almost_eq(Market.after_trade(0.0, -50, ECONOMY), -0.10, 0.0001, "selling 50 lowers it 10%")
	assert_almost_eq(Market.after_trade(0.25, 100, ECONOMY), 0.30, 0.0001, "capped at +30%")
	assert_almost_eq(Market.after_trade(-0.25, -100, ECONOMY), -0.30, 0.0001, "capped at -30%")
	assert_almost_eq(Market.recovered(0.2, 1, ECONOMY), 0.16, 0.0001, "recovers 20% a day")
	assert_almost_eq(Market.recovered(0.2, 3, ECONOMY), 0.1024, 0.0001, "compounding over days")
	assert_eq(Market.recovered(0.0004, 1, ECONOMY), 0.0, "tiny leftovers clear")


func test_cargo_hold() -> void:
	assert_eq(Market.max_buy(1000, 40, 10.0, 1.0), 10, "EC3: limited by space")
	assert_eq(Market.max_buy(100, 40, 10.0, 1.0), 2, "limited by credits")
	assert_eq(Market.max_buy(1000, 40, 10.0, 3.0), 3, "heavier goods take more room")
	var cargo: Array = Market.with_units([], "food", 5)
	cargo = Market.with_units(cargo, "water", 2)
	assert_eq(Market.held(cargo, "food"), 5)
	assert_almost_eq(Market.used_tons(cargo, {"food": 1.0, "water": 2.0}), 9.0, 0.0001, "tons by mass")
	cargo = Market.with_units(cargo, "food", -5)
	assert_eq(cargo.size(), 1, "selling everything removes the entry")
	assert_eq(Market.held(cargo, "food"), 0)


func test_scooping_takes_what_fits() -> void:
	# EC8: a canister of 5 food (1 t) and 4 ore (2 t) into a 9-ton hold.
	var result: Dictionary = Market.take_what_fits([{"commodity": "food", "units": 5}, {"commodity": "ore", "units": 4}], 9.0, {"food": 1.0, "ore": 2.0})
	assert_eq(result["taken"], [{"commodity": "food", "units": 5}, {"commodity": "ore", "units": 2}], "fills the hold in order")
	assert_eq(result["left"], [{"commodity": "ore", "units": 2}], "the rest stays in the canister")
	assert_eq(Market.take_what_fits([{"commodity": "food", "units": 3}], 0.0, {"food": 1.0})["taken"], [], "a full hold takes nothing")


func test_random_ai_load() -> void:
	# EC6: AI holds stay within capacity × fill and use known goods.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 20:
		var cargo: Array = Market.random_load(rng, 120.0, 0.8, ["food", "ore"], {"food": 1.0, "ore": 2.0})
		assert_true(Market.used_tons(cargo, {"food": 1.0, "ore": 2.0}) <= 96.0 + 0.001, "within capacity × fill")
		assert_true(cargo.all(func(c: Dictionary) -> bool: return c["commodity"] in ["food", "ore"] and int(c["units"]) > 0), "known goods, no empty entries")
	assert_eq(Market.random_load(rng, 0.0, 1.0, ["food"], {}), [], "no hold, no cargo")


func test_a_round_trip_never_makes_money() -> void:
	# EC5: buying then selling back at one port always loses at least the spread, however big.
	for units: int in [1, 10, 27, 60, 120, 400]:
		for start: float in [-0.3, -0.1, 0.0, 0.2, 0.3]:
			var paid: int = Market.buy_total(420.0, "medium", start, 1.0, units, ECONOMY)
			var after: float = Market.after_trade(start, units, ECONOMY)
			var got: int = Market.sell_total(420.0, "medium", after, 1.0, units, ECONOMY)
			assert_true(got < paid, "%d units from %+.0f%%: paid %d, got back %d" % [units, start * 100.0, paid, got])
	assert_true(Market.buy_total(420.0, "medium", 0.0, 1.0, 100, ECONOMY) > 100 * Market.buy_price(420.0, "medium", 0.0, 1.0, ECONOMY), "a big buy pays for the price it pushes up")
