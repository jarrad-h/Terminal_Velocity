class_name Encounter
extends RefCounted
## PS5: hostile persistent entities sharing a system off-screen fight it out
## on a day tick: strength compared with randomness; the loser loses ships,
## the winner takes damage. Pure.


## Fleet strength: each ship's strength × its hull fraction.
static func strength(ships: Array, ship_strength: Dictionary) -> float:
	var total: float = 0.0
	for s: Dictionary in ships:
		total += float(ship_strength.get(s["ship"], 1.0)) * float(s["hull"])
	return total


## True if side A wins: each side's strength × a roll in 1 ± randomness.
static func a_wins(strength_a: float, strength_b: float, roll_a: float, roll_b: float, randomness: float) -> bool:
	var a: float = strength_a * (1.0 + (roll_a * 2.0 - 1.0) * randomness)
	var b: float = strength_b * (1.0 + (roll_b * 2.0 - 1.0) * randomness)
	return a >= b


## The loser's fleet after a defeat: `loss_fraction` of its ships (rounded up)
## lost, weakest first; the rest take `damage` off their hull (down to `floor`).
static func after_defeat(ships: Array, loss_fraction: float, damage: float, floor_hull: float) -> Array:
	var sorted: Array = ships.duplicate(true)
	sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["hull"]) < float(y["hull"]))
	var lose: int = mini(sorted.size(), ceili(sorted.size() * clampf(loss_fraction, 0.0, 1.0) - 0.0001))
	var kept: Array = sorted.slice(lose)
	return Encounter.after_damage(kept, damage, floor_hull)


## Every ship takes `damage` off its hull, down to `floor_hull` (negative
## damage repairs).
static func after_damage(ships: Array, damage: float, floor_hull: float) -> Array:
	var result: Array = ships.duplicate(true)
	for s: Dictionary in result:
		s["hull"] = maxf(float(s["hull"]) - damage, floor_hull)
	return result
