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
