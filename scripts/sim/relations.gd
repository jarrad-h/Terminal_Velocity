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


## G3 / A8: a government's ship treats the player as hostile when the player's
## record is below its crime threshold, or when provoked this visit.
static func hostile_to_player(gov: GovernmentDef, record: float, provoked: bool) -> bool:
	if gov == null:
		return provoked
	return provoked or record < gov.crime_threshold


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
