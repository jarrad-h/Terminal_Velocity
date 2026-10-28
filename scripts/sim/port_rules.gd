class_name PortRules
extends RefCounted
## S2, G4, C9, C10: pure rules for landing, boarding and rescue.

## Boarding window options (C9).
const TAKE: String = "take"
const ASSIST: String = "assist"
const SCUTTLE: String = "scuttle"
const LEAVE: String = "leave"


## S2: "" if the ship can land; otherwise "far" or "fast".
static func landing_check(distance_to_centre: float, planet_radius: float, radius_fraction: float, speed: float, max_speed: float) -> String:
	if distance_to_centre > planet_radius * radius_fraction:
		return "far"
	if speed > max_speed:
		return "fast"
	return ""


## G4: planets with no government always accept; others need record >= min_record.
static func landing_allowed(planet_government: String, record: float, min_record: float) -> bool:
	return planet_government == "" or record >= min_record


## C9: "" if boarding can run; otherwise "far" or "fast". `gap` is the
## distance between the two hulls' edges.
static func boarding_check(gap: float, max_gap: float, relative_speed: float, max_speed: float) -> String:
	if gap > max_gap:
		return "far"
	if relative_speed > max_speed:
		return "fast"
	return ""


## C9: credits aboard = hull range × pool wealth, `roll` in [0, 1).
static func board_credits(hull_range: Vector2, wealth_factor: float, roll: float) -> int:
	return roundi(lerpf(hull_range.x, hull_range.y, roll) * wealth_factor)


## C9: options still open. Looting rules out assisting.
static func board_options(looted: bool) -> Array[String]:
	if looted:
		return [SCUTTLE, LEAVE]
	return [TAKE, ASSIST, SCUTTLE, LEAVE]


## C10: rescue fee as a share of the player's credits.
static func rescue_fee(credits: int, fee_pct: float) -> int:
	return roundi(maxf(credits, 0) * fee_pct / 100.0)


## C10: index of the nearest landable object that accepts the player (G4),
## else the nearest landable one, else -1. `records`: government -> record.
static func rescue_port(objects: Array[SystemObjectDef], from: Vector2, records: Dictionary, default_record: float) -> int:
	var best_ok: int = -1
	var best_any: int = -1
	for i: int in objects.size():
		var obj: SystemObjectDef = objects[i]
		if not obj.landable:
			continue
		var d2: float = from.distance_squared_to(obj.position)
		if best_any == -1 or d2 < from.distance_squared_to(objects[best_any].position):
			best_any = i
		var record: float = records.get(obj.government, default_record)
		if landing_allowed(obj.government, record, obj.min_record):
			if best_ok == -1 or d2 < from.distance_squared_to(objects[best_ok].position):
				best_ok = i
	return best_ok if best_ok != -1 else best_any
