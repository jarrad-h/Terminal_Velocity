class_name Trading
extends RefCounted
## EC1–EC5: trading at a port with the live game: prices from the commodity,
## the port's tier, its saturation (system memory) and active price events,
## and buying and selling against the player's credits and hold. The maths
## is Market's (pure); this joins it to GameState and the data.


## {"buy": int, "sell": int, "tier": String, "event": float, "illegal": bool}
## for `commodity` at `port` in `system_id`, or {} if it isn't traded there.
static func quote(system_id: String, port: SystemObjectDef, commodity: String) -> Dictionary:
	var def: CommodityDef = DataRegistry.get_commodity(commodity)
	if def == null or not port.market.has(commodity):
		return {}
	var economy: Dictionary = DataRegistry.settings["economy"]
	var event: float = GameState.price_factor(system_id, port, commodity)
	var buy: int = Market.buy_price(def.base_price, port.market[commodity], GameState.memory.saturation(system_id, port.id, commodity), event, economy)
	return {"buy": buy, "sell": Market.sell_price(buy, economy), "tier": port.market[commodity], "event": event,
		"illegal": port.government != "" and def.illegal_to.has(port.government)}


## EC3: tons the ship's cargo takes up.
static func used_tons(ship: Ship) -> float:
	return Market.used_tons(ship.cargo, masses())


static func free_tons(ship: Ship) -> float:
	return maxf(ship.def.cargo - used_tons(ship), 0.0)


## EC3: buys up to `units` (as many as credits and space allow). Returns units bought.
static func buy(system_id: String, port: SystemObjectDef, ship: Ship, commodity: String, units: int) -> int:
	var q: Dictionary = quote(system_id, port, commodity)
	if q.is_empty() or units <= 0:
		return 0
	var def: CommodityDef = DataRegistry.get_commodity(commodity)
	var n: int = mini(units, Market.max_buy(GameState.credits, q["buy"], free_tons(ship), def.mass))
	var economy: Dictionary = DataRegistry.settings["economy"]
	var saturation: float = GameState.memory.saturation(system_id, port.id, commodity)
	while n > 0 and Market.buy_total(def.base_price, q["tier"], saturation, q["event"], n, economy) > GameState.credits:
		n -= 1  # the price climbs as you buy: afford fewer
	if n <= 0:
		return 0
	GameState.add_credits(-Market.buy_total(def.base_price, q["tier"], saturation, q["event"], n, economy))
	ship.cargo = Market.with_units(ship.cargo, commodity, n)
	_saturate(system_id, port, commodity, n)
	return n


## EC3: sells up to `units` of what the ship holds. Returns units sold.
static func sell(system_id: String, port: SystemObjectDef, ship: Ship, commodity: String, units: int) -> int:
	var q: Dictionary = quote(system_id, port, commodity)
	var n: int = mini(units, Market.held(ship.cargo, commodity))
	if q.is_empty() or n <= 0:
		return 0
	GameState.add_credits(Market.sell_total(DataRegistry.get_commodity(commodity).base_price, q["tier"],
		GameState.memory.saturation(system_id, port.id, commodity), q["event"], n, DataRegistry.settings["economy"]))
	ship.cargo = Market.with_units(ship.cargo, commodity, -n)
	_saturate(system_id, port, commodity, -n)
	return n


## EC5: `units` changed hands at the port (+ bought from it, − sold to it).
static func move_market(system_id: String, port: SystemObjectDef, commodity: String, units: int) -> void:
	_saturate(system_id, port, commodity, units)


static func _saturate(system_id: String, port: SystemObjectDef, commodity: String, units: int) -> void:
	var now: float = GameState.memory.saturation(system_id, port.id, commodity)
	GameState.memory.set_saturation(system_id, port.id, commodity, Market.after_trade(now, units, DataRegistry.settings["economy"]))


## Commodity id -> tons per unit.
static func masses() -> Dictionary:
	return DataRegistry.commodity_masses()
