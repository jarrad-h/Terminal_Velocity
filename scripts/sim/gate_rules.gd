class_name GateRules
extends RefCounted
## Gate travel rules (TR5, TR6). Pure.

## dock_problem / travel_problem results.
const CLOSED: String = "closed"
const RECORD: String = "record"
const CREDITS: String = "credits"


## TR6: a gate's open condition, until the milestone 7 condition grammar reads
## the same field: "" is always open, "name" is open while that flag is set
## (non-zero), "!name" while it isn't.
static func is_open(open_condition: String, flags: Dictionary) -> bool:
	if open_condition == "":
		return true
	if open_condition.begins_with("!"):
		return int(flags.get(open_condition.substr(1), 0)) == 0
	return int(flags.get(open_condition, 0)) != 0


## True for "", "name" or "!name" with a lowercase snake_case name.
static func is_valid_condition(open_condition: String) -> bool:
	if open_condition == "":
		return true
	var name: String = open_condition.trim_prefix("!")
	if name == "":
		return false
	for c: String in name:
		if not (c == "_" or (c >= "a" and c <= "z") or (c >= "0" and c <= "9")):
			return false
	return true


## TR6: why the player can't dock with a gate, or "".
static func dock_problem(open: bool, record: float, min_record: float) -> String:
	if not open:
		return CLOSED
	if record < min_record:
		return RECORD
	return ""


## TR5, TR6: why the player can't travel to a linked gate, or "". The fee is
## the departure gate's.
static func travel_problem(destination_open: bool, credits: int, fee: int) -> String:
	if not destination_open:
		return CLOSED
	if credits < fee:
		return CREDITS
	return ""
