class_name EntityState
extends RefCounted
## PS2: one persistent entity's summary: where it is (a system, or in transit
## with an arrival day), its progress through its orders, its ships' state and
## any grudge. Plain values with to_dict / from_dict (SV1).

var id: String
var alive: bool = true
## The system it's in; "" while in transit.
var location: String = ""
var transit_from: String = ""
var transit_to: String = ""
var arrive_day: int = 0
## The day it reached `location`, and the last day it stays there.
var arrived_day: int = 0
var leave_day: int = 0
## Where it came from on its last arrival ("" = it started here), so it can
## be seen arriving on that side (PS4).
var came_from: String = ""
## Patrol: index of the route stop it's heading for or at.
var route_index: int = 0
## [{"ship": String, "hull": 0–1, "shield": 0–1}]
var ships: Array = []
## Follows the player until this day (-1 = no grudge).
var grudge_until: int = -1


func in_transit() -> bool:
	return transit_to != ""


func to_dict() -> Dictionary:
	return {"id": id, "alive": alive, "location": location, "transit_from": transit_from, "transit_to": transit_to,
		"arrive_day": arrive_day, "arrived_day": arrived_day, "leave_day": leave_day, "route_index": route_index, "came_from": came_from,
		"ships": ships.duplicate(true), "grudge_until": grudge_until}


static func from_dict(data: Dictionary) -> EntityState:
	var s := EntityState.new()
	s.id = str(data.get("id", ""))
	s.alive = bool(data.get("alive", true))
	s.location = str(data.get("location", ""))
	s.transit_from = str(data.get("transit_from", ""))
	s.transit_to = str(data.get("transit_to", ""))
	s.arrive_day = int(data.get("arrive_day", 0))
	s.arrived_day = int(data.get("arrived_day", 0))
	s.leave_day = int(data.get("leave_day", 0))
	s.route_index = int(data.get("route_index", 0))
	s.came_from = str(data.get("came_from", ""))
	s.ships = (data.get("ships", []) as Array).duplicate(true)
	s.grudge_until = int(data.get("grudge_until", -1))
	return s
