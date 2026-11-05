class_name Market
extends RefCounted
## EC1, EC3, EC5: prices and trades. Pure: settings (game.json "economy") and
## state come in, numbers come out.
##   price = base × tier × (1 + saturation) × events, rounded, at least 1
##   the player sells for `sell_spread_pct` less
## Saturation is a fraction (+0.1 = 10% dearer): buying raises it, selling
## lowers it, capped either way, and it recovers towards 0 each day.

const TIERS: Array[String] = ["low", "medium", "high"]


## EC1: what the port charges per unit.
static func buy_price(base: float, tier: String, saturation: float, event_factor: float, economy: Dictionary) -> int:
	var tier_factor: float = float(economy["tiers"].get(tier, 1.0))
	return maxi(1, roundi(base * tier_factor * (1.0 + saturation) * event_factor))


## EC1: what the port pays per unit: the buy price less the spread.
static func sell_price(buy: int, economy: Dictionary) -> int:
	return maxi(1, floori(buy * (1.0 - float(economy["sell_spread_pct"]) / 100.0)))


## EC5: what buying `units` costs in all: each unit priced at the saturation
## midway through the trade, so a big buy pays for the price it pushes up
## (and buying then selling back always loses the spread).
static func buy_total(base: float, tier: String, saturation: float, event_factor: float, units: int, economy: Dictionary) -> int:
	if units <= 0:
		return 0
	var mid: float = (saturation + after_trade(saturation, units, economy)) / 2.0
	return buy_price(base, tier, mid, event_factor, economy) * units


## EC5: what selling `units` earns in all (midway saturation, as above).
static func sell_total(base: float, tier: String, saturation: float, event_factor: float, units: int, economy: Dictionary) -> int:
	if units <= 0:
		return 0
	var mid: float = (saturation + after_trade(saturation, -units, economy)) / 2.0
	return sell_price(buy_price(base, tier, mid, event_factor, economy), economy) * units


## EC5: saturation after `units` change hands at a port (+ bought from the
## port, − sold to it).
static func after_trade(saturation: float, units: int, economy: Dictionary) -> float:
	var cfg: Dictionary = economy["saturation"]
	var cap: float = float(cfg["cap_pct"]) / 100.0
	return clampf(saturation + units / 10.0 * float(cfg["pct_per_10_units"]) / 100.0, -cap, cap)


## EC5: saturation after `days` of recovery.
static func recovered(saturation: float, days: int, economy: Dictionary) -> float:
	var keep: float = 1.0 - clampf(float(economy["saturation"]["recovery_per_day"]), 0.0, 1.0)
	var out: float = saturation * pow(keep, maxi(days, 0))
	return 0.0 if absf(out) < 0.0005 else out


## EC3: the most units the player can buy: by credits, by free space (tons)
## and by the unit's mass.
static func max_buy(credits: int, price: int, free_tons: float, mass: float) -> int:
	if price <= 0 or mass <= 0.0:
		return 0
	return maxi(0, mini(floori(float(credits) / price), floori(free_tons / mass + 0.000001)))


## EC3: tons used by a cargo list [{"commodity", "units"}] (`masses`: id -> tons per unit).
static func used_tons(cargo: Array, masses: Dictionary) -> float:
	var total: float = 0.0
	for item: Dictionary in cargo:
		total += float(item["units"]) * float(masses.get(item["commodity"], 1.0))
	return total


## EC3: units of `commodity` held.
static func held(cargo: Array, commodity: String) -> int:
	for item: Dictionary in cargo:
		if item["commodity"] == commodity:
			return int(item["units"])
	return 0


## EC3: the cargo list with `units` (+/−) of `commodity` added; empty entries go.
static func with_units(cargo: Array, commodity: String, units: int) -> Array:
	var out: Array = []
	var found: bool = false
	for item: Dictionary in cargo:
		if item["commodity"] == commodity:
			found = true
			var left: int = int(item["units"]) + units
			if left > 0:
				out.append({"commodity": commodity, "units": left})
		else:
			out.append(item.duplicate())
	if not found and units > 0:
		out.append({"commodity": commodity, "units": units})
	return out


## EC8: scooping a canister: as much as fits in `free_tons`, cheapest
## commodities first left behind (taken in list order). {"taken", "left"}.
static func take_what_fits(cargo: Array, free_tons: float, masses: Dictionary) -> Dictionary:
	var taken: Array = []
	var left: Array = []
	var room: float = free_tons
	for item: Dictionary in cargo:
		var mass: float = float(masses.get(item["commodity"], 1.0))
		var fit: int = mini(int(item["units"]), floori(room / mass + 0.000001)) if mass > 0.0 else int(item["units"])
		if fit > 0:
			taken.append({"commodity": item["commodity"], "units": fit})
			room -= fit * mass
		if int(item["units"]) - fit > 0:
			left.append({"commodity": item["commodity"], "units": int(item["units"]) - fit})
	return {"taken": taken, "left": left}


## EC6: a random hold for an AI ship: 1–3 commodities from `ids` filling
## `fill` (0–1) of `capacity` tons. `masses`: id -> tons per unit.
static func random_load(rng: RandomNumberGenerator, capacity: float, fill: float, ids: Array, masses: Dictionary) -> Array:
	var cargo: Array = []
	if ids.is_empty() or capacity <= 0.0 or fill <= 0.0:
		return cargo
	var room: float = capacity * clampf(fill, 0.0, 1.0)
	var kinds: int = mini(rng.randi_range(1, 3), ids.size())
	var pool: Array = ids.duplicate()
	for k: int in kinds:
		var id: String = pool.pop_at(rng.randi() % pool.size())
		var mass: float = float(masses.get(id, 1.0))
		var share: float = room / float(kinds - k)
		var units: int = floori(share / mass + 0.000001)
		if units > 0:
			cargo = with_units(cargo, id, units)
			room -= units * mass
	return cargo

