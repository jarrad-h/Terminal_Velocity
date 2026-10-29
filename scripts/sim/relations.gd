class_name Relations
extends RefCounted
## G1–G3, A5, A8: pure rules for who is friend or foe, the legal record and
## the odds check. Takes definitions and numbers, returns answers.


## G1: hostile when either government lists the other as an enemy.
static func governments_hostile(a: GovernmentDef, b: GovernmentDef) -> bool:
	if a == null or b == null or a.id == b.id:
		return false
	return b.id in a.enemies or a.id in b.enemies


## Same government, or either lists the other as an ally (C11 friendly fire).
static func allied(a: GovernmentDef, b: GovernmentDef) -> bool:
	if a == null or b == null:
		return false
	return a.id == b.id or b.id in a.allies or a.id in b.allies


## G3: a government's ships treat the player as hostile while the player's
## record with it is below its crime threshold. (A8 per-ship grievance is
## tracked on the ship itself.)
static func hostile_to_player(gov: GovernmentDef, record: float) -> bool:
	return gov != null and record < gov.crime_threshold


## G2: the record after one act ("shoot", "disable", "board", "kill").
static func after_penalty(record: float, gov: GovernmentDef, act: String) -> float:
	if gov == null:
		return record
	return record - float(gov.penalties.get(act, 0.0))


## A5: engage only if the enemy side's strength is at most max_odds × our own.
static func odds_ok(own_strength: float, enemy_strength: float, max_odds: float) -> bool:
	if enemy_strength <= 0.0:
		return true
	return own_strength > 0.0 and enemy_strength <= max_odds * own_strength


## C11: damage multiplier for a hit. AI shots on their own or allied
## governments' ships do `friendly_fire_pct` %; everything else does full damage.
static func damage_scale(shooter_is_player: bool, shooter_gov: GovernmentDef, target_gov: GovernmentDef, friendly_fire_pct: float) -> float:
	if shooter_is_player or not allied(shooter_gov, target_gov):
		return 1.0
	return maxf(friendly_fire_pct, 0.0) / 100.0


## C9: the record after the player assists one of the government's disabled ships.
static func after_assist(record: float, gov: GovernmentDef) -> float:
	return record + (gov.assist_reward if gov != null else 0.0)


## G5: the player's standing with one ship: "hostile" (it treats the player
## as hostile), "angry" (grievance, not yet hostile, A8), "friendly" (record at
## or above the government's friendly_record) or "neutral".
static func standing(hostile: bool, grievance: float, gov: GovernmentDef, record: float) -> String:
	if hostile:
		return "hostile"
	if grievance > 0.0:
		return "angry"
	if gov != null and record >= gov.friendly_record:
		return "friendly"
	return "neutral"


## H4, G3: -1 when a record change takes the player below the government's
## crime threshold, +1 when it lifts them back above it, else 0.
static func threshold_crossing(gov: GovernmentDef, before: float, after: float) -> int:
	if gov == null:
		return 0
	var was: bool = hostile_to_player(gov, before)
	var now: bool = hostile_to_player(gov, after)
	if now and not was:
		return -1
	if was and not now:
		return 1
	return 0
