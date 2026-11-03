class_name Behaviour
extends RefCounted
## A4, A5, A7: how a ship's group (government + role) and its individual
## personality combine. Pure: numbers and words in, decisions out.


## A5 + A7: the government's max_odds scaled by the personality.
static func max_odds(government_odds: float, odds_factor: float) -> float:
	return government_odds * odds_factor


## A4 + A7: flee threshold in shield % (government's, shifted by the personality), 0–100.
static func flee_threshold(government_pct: float, offset: float) -> float:
	return clampf(government_pct + offset, 0.0, 100.0)


## A4: below the threshold? Ships with no shields never flee on this rule.
static func should_flee(shield: float, max_shield: float, threshold_pct: float) -> bool:
	return max_shield > 0.0 and shield / max_shield * 100.0 < threshold_pct


## A1 + A7: fight back when attacked? "role": traders flee, others fight.
static func fights_back(role: String, when_attacked: String) -> bool:
	match when_attacked:
		"fight":
			return true
		"flee":
			return false
	return role != "trader"


## A2, A3 + A7: attack enemies on sight? "role": warships and pirates do, traders don't.
static func starts_fights(role: String, setting: String) -> bool:
	match setting:
		"on_sight":
			return true
		"never":
			return false
	return role == "warship" or role == "pirate"


## A13: keep firing on a disabled enemy until it's destroyed? `policy`:
## the government's on_disabled ("kill" or "leave"). Against the player, a
## record at or below `kill_record` (when `has_kill_record`) means kill anyway.
static func finishes_off(policy: String, target_is_player: bool, record: float, has_kill_record: bool, kill_record: float) -> bool:
	if policy == "kill":
		return true
	return target_is_player and has_kill_record and record <= kill_record

