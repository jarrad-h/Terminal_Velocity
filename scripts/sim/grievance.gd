class_name Grievance
extends RefCounted
## A8: leniency for the player's accidental fire. Grievance is the share (%)
## of a ship's total shield + armour the player has damaged, draining over
## time; the ship turns hostile only once it passes its tolerance.


## Grievance after the player does `damage` to a ship with `total_health` max shield + armour.
static func add(current_pct: float, damage: float, total_health: float) -> float:
	if total_health <= 0.0:
		return INF
	return current_pct + damage / total_health * 100.0


## Grievance after `delta` seconds of forgiveness.
static func decay(current_pct: float, forgiveness_pct_per_s: float, delta: float) -> float:
	return maxf(current_pct - forgiveness_pct_per_s * delta, 0.0)


## The government's tolerance shaded by the personality (A7).
static func tolerance(government_tolerance_pct: float, personality_factor: float) -> float:
	return government_tolerance_pct * personality_factor


static func exceeded(current_pct: float, tolerance_pct: float) -> bool:
	return current_pct > tolerance_pct
