class_name DamageModel
extends RefCounted
## C5–C7: pure shield/armour maths.
## While shields are up a hit spends its shield damage on them; if that empties
## the shield, the unspent fraction of the hit carries its armour damage
## through. With shields down, armour takes the full armour damage.


## Returns Vector2(shield, armor) after one hit.
static func apply(shield: float, armor: float, damage_shield: float, damage_armor: float) -> Vector2:
	if shield > 0.0:
		if damage_shield <= 0.0:
			return Vector2(shield, armor)
		if damage_shield <= shield:
			return Vector2(shield - damage_shield, armor)
		var leftover: float = 1.0 - shield / damage_shield
		return Vector2(0.0, maxf(armor - damage_armor * leftover, 0.0))
	return Vector2(0.0, maxf(armor - damage_armor, 0.0))


## C6: shield after `delta` seconds of recharge, capped at max.
static func regen(shield: float, max_shield: float, rate: float, delta: float) -> float:
	return minf(shield + rate * delta, max_shield)


## C7: disabled at or below `disable_fraction` of max armour, but not destroyed.
static func is_disabled(armor: float, max_armor: float, disable_fraction: float) -> bool:
	return armor > 0.0 and armor <= max_armor * disable_fraction


## C6: shields recharge only once `delay` seconds have passed without damage.
static func can_regen(time_since_damage: float, delay: float) -> bool:
	return time_since_damage >= delay


## C12: damage multiplier at `distance` for a weapon with this range and
## falloff. Full damage up to start_pct % of range, then linear down to
## min_pct % at full range (and beyond). start_pct 100 = no falloff.
static func falloff(distance: float, max_range: float, start_pct: float, min_pct: float) -> float:
	if max_range <= 0.0 or start_pct >= 100.0:
		return 1.0
	var start: float = max_range * start_pct / 100.0
	if distance <= start:
		return 1.0
	var t: float = clampf((distance - start) / (max_range - start), 0.0, 1.0)
	return lerpf(1.0, min_pct / 100.0, t)
