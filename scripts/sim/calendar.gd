class_name Calendar
extends RefCounted
## TM1: the game date is a whole day count from a start date (game.json
## calendar.start_date, "YYYY-MM-DD"), shown as a calendar date. Pure.

const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const SECONDS_PER_DAY: int = 86400


## True for a real date written "YYYY-MM-DD".
static func is_valid_date(text: String) -> bool:
	var parts: PackedStringArray = text.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part: String in parts:
		if not part.is_valid_int():
			return false
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	return month >= 1 and month <= 12 and day >= 1 and day <= days_in_month(parts[0].to_int(), month)


static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap: bool = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


## {"year", "month", "day"} of `day` days after `start_date`.
static func date_of(start_date: String, day: int) -> Dictionary:
	var unix: int = Time.get_unix_time_from_datetime_string(start_date) + day * SECONDS_PER_DAY
	var d: Dictionary = Time.get_date_dict_from_unix_time(unix)
	return {"year": d["year"], "month": d["month"], "day": d["day"]}


## "14 Mar 3200".
static func date_text(start_date: String, day: int) -> String:
	var d: Dictionary = date_of(start_date, day)
	return "%d %s %d" % [d["day"], MONTHS[d["month"] - 1], d["year"]]
