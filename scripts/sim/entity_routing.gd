class_name EntityRouting
extends RefCounted
## PS3: persistent entities travel by the player's rules: hyperlane jumps
## (days by lane length and the fleet's jump speed) and gate links (the link's
## days) where `gate_ok` allows the gate at both ends. Pure.


## Fewest-days hops from `from` to `to`: [{"system", "days", "via": "lane" | "gate"}].
## Empty when already there or unreachable.
static func plot(galaxy: GalaxyDef, from: String, to: String, jump_speed: float, gate_ok: Callable) -> Array[Dictionary]:
	var hops: Array[Dictionary] = []
	if from == to or not galaxy.has_system(from) or not galaxy.has_system(to):
		return hops
	var best: Dictionary = {from: Vector2i(0, 0)}
	var previous: Dictionary = {}  # system -> {"from", "days", "via"}
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
		for edge: Dictionary in _edges(galaxy, current, jump_speed, gate_ok):
			var next: String = edge["system"]
			if done.has(next):
				continue
			var cost: Vector2i = best[current] + Vector2i(edge["days"], 1)
			if not best.has(next) or _less(cost, best[next]):
				best[next] = cost
				previous[next] = {"from": current, "days": edge["days"], "via": edge["via"]}
				if next not in open:
					open.append(next)
	if not previous.has(to):
		return hops
	var step: String = to
	while step != from:
		var link: Dictionary = previous[step]
		hops.push_front({"system": step, "days": link["days"], "via": link["via"]})
		step = link["from"]
	return hops


static func total_days(hops: Array[Dictionary]) -> int:
	var days: int = 0
	for hop: Dictionary in hops:
		days += int(hop["days"])
	return days


static func _edges(galaxy: GalaxyDef, system_id: String, jump_speed: float, gate_ok: Callable) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for next: String in Hyperlanes.neighbours(galaxy, system_id):
		edges.append({"system": next, "days": Hyperlanes.jump_days(Hyperlanes.lane_length(galaxy, system_id, next), jump_speed), "via": "lane"})
	if gate_ok.call(system_id):
		for link: Dictionary in galaxy.gate_destinations(system_id):
			if gate_ok.call(link["system"]):
				edges.append({"system": link["system"], "days": link["days"], "via": "gate"})
	return edges


static func _less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)
