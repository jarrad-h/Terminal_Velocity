class_name NewsLog
extends RefCounted
## PS7: recent off-screen events and announced movements, by day. Saved (SV1).

## [{"day": int, "text": String}], oldest first.
var items: Array = []


func add(day: int, text: String) -> void:
	items.append({"day": day, "text": text})


## Items from the last `days` days, newest first, at most `max_items`.
func recent(today: int, days: int, max_items: int) -> Array:
	var result: Array = []
	for i: int in range(items.size() - 1, -1, -1):
		if int(items[i]["day"]) <= today - days:
			break
		result.append(items[i])
		if result.size() >= max_items:
			break
	return result


## Drops items older than `keep_days`.
func prune(today: int, keep_days: int) -> void:
	items = items.filter(func(item: Dictionary) -> bool: return int(item["day"]) > today - keep_days)


func to_dict() -> Dictionary:
	return {"items": items.duplicate(true)}


static func from_dict(data: Dictionary) -> NewsLog:
	var log := NewsLog.new()
	log.items = (data.get("items", []) as Array).duplicate(true)
	return log
