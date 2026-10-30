class_name Hyperlanes
extends RefCounted
## Hyperlane travel rules (TR1–TR4, TR7, TR8, TM2). Pure: takes the galaxy
## definition and plain values. `hidden` is a set (id -> true) of systems the
## player can't see; they and their lanes are left out of every query.

## jump_problem results.
const NO_DESTINATION: String = "no_destination"
const NOT_ADJACENT: String = "not_adjacent"
const INSIDE: String = "inside"
const NO_FUEL: String = "fuel"


## TR1: systems one hyperlane away, sorted.
static func neighbours(galaxy: GalaxyDef, system_id: String, hidden: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	if hidden.has(system_id):
		return result
	for lane: Dictionary in galaxy.lanes:
		var other: String = ""
		if lane["from"] == system_id:
			other = lane["to"]
		elif lane["to"] == system_id:
			other = lane["from"]
		if other != "" and not hidden.has(other) and other not in result:
			result.append(other)
	result.sort()
	return result


static func are_adjacent(galaxy: GalaxyDef, a: String, b: String, hidden: Dictionary = {}) -> bool:
	return b in neighbours(galaxy, a, hidden)


## Straight-line distance on the galaxy map, map units.
static func lane_length(galaxy: GalaxyDef, a: String, b: String) -> float:
	return galaxy.positions[a].distance_to(galaxy.positions[b])


## TM2: days for one jump: length ÷ jump speed, rounded up, at least 1.
static func jump_days(length: float, jump_speed: float) -> int:
	return maxi(1, ceili(length / maxf(jump_speed, 0.0001) - 0.000001))


## TR8: fuel for one jump. Flat per jump for now; the lane length is passed
## so a distance-based rule can replace this without touching callers.
static func jump_fuel(fuel_per_jump: float, _length: float) -> float:
	return fuel_per_jump


## TR7: the route from `from` to `to` with the fewest days (then fewest
## jumps), excluding `from`. Empty when already there or unreachable.
static func plot_route(galaxy: GalaxyDef, from: String, to: String, jump_speed: float, hidden: Dictionary = {}) -> Array[String]:
	var route: Array[String] = []
	if from == to or not galaxy.has_system(from) or not galaxy.has_system(to) or hidden.has(to):
		return route
	# Dijkstra on (days, jumps); the cluster is small, so a linear scan for the next node is fine.
	var best: Dictionary = {from: Vector2i(0, 0)}
	var previous: Dictionary = {}
	var open: Array[String] = [from]
	var done: Dictionary = {}
	while not open.is_empty():
		var current: String = open[0]
		for id: String in open:
			if _less(best[id], best[current]):
				current = id
		open.erase(current)
		if current == to:
			break
		done[current] = true
		for next: String in neighbours(galaxy, current, hidden):
			if done.has(next):
				continue
			var cost: Vector2i = best[current] + Vector2i(jump_days(lane_length(galaxy, current, next), jump_speed), 1)
			if not best.has(next) or _less(cost, best[next]):
				best[next] = cost
				previous[next] = current
				if next not in open:
					open.append(next)
	if not previous.has(to):
		return route
	var step: String = to
	while step != from:
		route.push_front(step)
		step = previous[step]
	return route


## TR7: {"days": int, "fuel": float, "jumps": int} for flying `route` from `from`.
static func route_cost(galaxy: GalaxyDef, from: String, route: Array[String], jump_speed: float, fuel_per_jump: float) -> Dictionary:
	var days: int = 0
	var fuel: float = 0.0
	var at: String = from
	for next: String in route:
		var length: float = lane_length(galaxy, at, next)
		days += jump_days(length, jump_speed)
		fuel += jump_fuel(fuel_per_jump, length)
		at = next
	return {"days": days, "fuel": fuel, "jumps": route.size()}


## TR2: unit direction of `to` from `from` on the galaxy map (+y down, as in space).
static func bearing(galaxy: GalaxyDef, from: String, to: String) -> Vector2:
	var offset: Vector2 = galaxy.positions[to] - galaxy.positions[from]
	return Vector2.UP if offset.is_zero_approx() else offset.normalized()


## TR2: why a jump can't start, or "" if it can. Checked in the order the
## player fixes them: pick a destination, reach the jump radius, have fuel.
static func jump_problem(destination: String, adjacent: bool, distance_from_centre: float, jump_radius: float, fuel: float, fuel_needed: float) -> String:
	if destination == "":
		return NO_DESTINATION
	if not adjacent:
		return NOT_ADJACENT
	if distance_from_centre < jump_radius:
		return INSIDE
	if fuel + 0.0001 < fuel_needed:
		return NO_FUEL
	return ""


## TR4: arrival on the side of the destination facing the origin, `grace`
## seconds of travel outside its jump radius (so the next jump can start at
## once), moving inward along the bearing (origin → destination) at `speed`.
static func arrival(travel_bearing: Vector2, jump_radius: float, speed: float, grace: float = 0.0) -> FlightState:
	var distance: float = jump_radius + speed * maxf(grace, 0.0)
	return FlightState.new(-travel_bearing * distance, travel_bearing * speed, Aim.rotation_of(travel_bearing))


static func _less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)
