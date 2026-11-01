class_name EntityRegistry
extends RefCounted
## PS2, PS3, PS5: every persistent entity's summary, moved one day at a time
## by its orders and the player's travel rules, with off-screen encounters
## between hostile entities. Pure: everything it needs from the game comes in
## a context dictionary:
##   galaxy: GalaxyDef            defs: {id -> PersistentEntityDef}
##   ship_strength, ship_speed: {ship id -> strength / jump speed}
##   gate_ok: Callable(def, system_id) -> bool   (may use that gate)
##   hostile: Callable(gov_a, gov_b) -> bool     exists: Callable(def) -> bool
##   name_of: Callable(system_id) -> String
##   player_system: where the player is, or is heading during a trip
##   rng: RandomNumberGenerator   settings: game.json entities.encounter
## step_day and depart return news lines (PS7).

## id -> EntityState
var states: Dictionary = {}


## Puts every entity at its start system, already there and staying a while.
func start(defs: Array, day: int, rng: RandomNumberGenerator) -> void:
	states.clear()
	for def: PersistentEntityDef in defs:
		states[def.id] = EntityRegistry.new_state(def, day, rng)


static func new_state(def: PersistentEntityDef, day: int, rng: RandomNumberGenerator) -> EntityState:
	var s := EntityState.new()
	s.id = def.id
	s.location = def.start_system
	s.arrived_day = day - 1
	s.leave_day = day + rng.randi_range(def.stay_days.x, def.stay_days.y)
	for entry: Dictionary in def.ships:
		for i: int in int(entry["count"]):
			s.ships.append({"ship": entry["ship"], "hull": 1.0, "shield": 1.0})
	if def.order_type == "patrol":
		s.route_index = maxi(def.route.find(def.start_system), 0)
	return s


## TM3: one day passes for every entity, then entities sharing a system fight.
func step_day(day: int, ctx: Dictionary) -> Array[String]:
	var news: Array[String] = []
	for id: String in states:
		var s: EntityState = states[id]
		var def: PersistentEntityDef = ctx["defs"].get(id)
		if def == null or not s.alive or not ctx["exists"].call(def):
			continue
		if s.grudge_until >= 0 and day > s.grudge_until:
			s.grudge_until = -1
		s.ships = Encounter.after_damage(s.ships, -float(ctx["settings"].get("repair_per_day", 0.0)), 0.0)
		for ship: Dictionary in s.ships:
			ship["hull"] = minf(float(ship["hull"]), 1.0)
		if s.in_transit():
			if day >= s.arrive_day:
				news.append_array(_arrive(s, def, day, ctx))
		elif day > s.leave_day:
			news.append_array(depart(s, def, day, ctx))
	news.append_array(_encounters(ctx))
	return news


## Starts the next hop towards the entity's current goal (also used when it
## leaves in front of the player, PS4). Returns news; stays put if there's
## nowhere to go.
func depart(s: EntityState, def: PersistentEntityDef, day: int, ctx: Dictionary) -> Array[String]:
	var target: String = target_of(s, def, ctx)
	if target == "" or target == s.location:
		s.leave_day = day
		return []
	var hops: Array[Dictionary] = EntityRouting.plot(ctx["galaxy"], s.location, target, _speed(s, ctx),
		func(system_id: String) -> bool: return ctx["gate_ok"].call(def, system_id))
	if hops.is_empty():
		s.leave_day = day
		return []
	var news: Array[String] = []
	if s.location != s.transit_from:  # announce at the start of a trip, not every hop
		var total: int = EntityRouting.total_days(hops)
		news.append("%s departs %s, due at %s in %d day%s" % [def.name, ctx["name_of"].call(s.location),
			ctx["name_of"].call(target), total, "" if total == 1 else "s"])
	s.transit_from = s.location
	s.transit_to = hops[0]["system"]
	s.transit_via = hops[0]["via"]
	s.arrive_day = day + int(hops[0]["days"])
	s.location = ""
	return news


## Where the entity is heading: the player while it holds a grudge or follows
## them, else by its orders. A patrol at its current stop moves on to the next.
func target_of(s: EntityState, def: PersistentEntityDef, ctx: Dictionary) -> String:
	if s.grudge_until >= 0 or def.order_type == "follow":
		return ctx["player_system"]
	match def.order_type:
		"travel":
			return def.destination
		"patrol":
			if s.location == def.route[s.route_index]:
				s.route_index = (s.route_index + 1) % def.route.size()
			return def.route[s.route_index]
	return def.start_system


## PS2: the player damaged it; it follows them for its grudge days.
func give_grudge(id: String, def: PersistentEntityDef, day: int) -> void:
	var s: EntityState = states.get(id)
	if s != null and s.alive and def.grudge_days > 0:
		s.grudge_until = day + def.grudge_days


## PS4: the ships' state after the player saw them; none left means dead.
func write_back(id: String, ships: Array) -> void:
	var s: EntityState = states.get(id)
	if s == null:
		return
	s.ships = ships
	if ships.is_empty():
		s.alive = false


func living_at(system_id: String) -> Array[EntityState]:
	var result: Array[EntityState] = []
	for s: EntityState in states.values():
		if s.alive and s.location == system_id:
			result.append(s)
	return result


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id: String in states:
		out[id] = (states[id] as EntityState).to_dict()
	return {"states": out}


static func from_dict(data: Dictionary) -> EntityRegistry:
	var registry := EntityRegistry.new()
	var raw: Dictionary = data.get("states", {})
	for id: String in raw:
		registry.states[id] = EntityState.from_dict(raw[id])
	return registry


func _arrive(s: EntityState, def: PersistentEntityDef, day: int, ctx: Dictionary) -> Array[String]:
	s.came_from = s.transit_from
	s.came_via = s.transit_via
	s.location = s.transit_to
	s.transit_to = ""
	s.arrived_day = day
	var goal: String = def.route[s.route_index] if def.order_type == "patrol" and s.grudge_until < 0 else target_of(s, def, ctx)
	if goal != s.location:
		s.transit_from = s.location  # passing through: straight on, no new announcement
		var news: Array[String] = depart(s, def, day, ctx)
		if s.in_transit():
			return news
	s.transit_from = ""
	s.leave_day = day + ctx["rng"].randi_range(def.stay_days.x, def.stay_days.y)
	return []


## PS5: hostile entities sharing a system (not the player's) fight once a day.
func _encounters(ctx: Dictionary) -> Array[String]:
	var news: Array[String] = []
	var by_system: Dictionary = {}
	for s: EntityState in states.values():
		var def: PersistentEntityDef = ctx["defs"].get(s.id)
		if not s.alive or s.in_transit() or def == null or not ctx["exists"].call(def) or s.location == ctx["player_system"]:
			continue
		if not by_system.has(s.location):
			by_system[s.location] = []
		by_system[s.location].append(s)
	var cfg: Dictionary = ctx["settings"]
	for system_id: String in by_system:
		var here: Array = by_system[system_id]
		for i: int in here.size():
			for j: int in range(i + 1, here.size()):
				var a: EntityState = here[i]
				var b: EntityState = here[j]
				var def_a: PersistentEntityDef = ctx["defs"][a.id]
				var def_b: PersistentEntityDef = ctx["defs"][b.id]
				if not a.alive or not b.alive or not ctx["hostile"].call(def_a.government, def_b.government):
					continue
				var a_won: bool = Encounter.a_wins(Encounter.strength(a.ships, ctx["ship_strength"]), Encounter.strength(b.ships, ctx["ship_strength"]),
					ctx["rng"].randf(), ctx["rng"].randf(), float(cfg["randomness"]))
				var winner: EntityState = a if a_won else b
				var loser: EntityState = b if a_won else a
				var winner_name: String = (def_a if a_won else def_b).name
				var loser_name: String = (def_b if a_won else def_a).name
				var before: int = loser.ships.size()
				loser.ships = Encounter.after_defeat(loser.ships, float(cfg["loser_losses"]), float(cfg["loser_damage"]), float(cfg["floor_hull"]))
				winner.ships = Encounter.after_damage(winner.ships, float(cfg["winner_damage"]), float(cfg["floor_hull"]))
				var where: String = ctx["name_of"].call(system_id)
				if loser.ships.is_empty():
					loser.alive = false
					news.append("%s destroyed %s at %s" % [winner_name, loser_name, where])
				else:
					var lost: int = before - loser.ships.size()
					news.append("%s drove off %s at %s (%d ship%s lost)" % [winner_name, loser_name, where, lost, "" if lost == 1 else "s"])
	return news


## A fleet moves at its slowest ship's jump speed (TM2).
func _speed(s: EntityState, ctx: Dictionary) -> float:
	var speed: float = INF
	for ship: Dictionary in s.ships:
		speed = minf(speed, float(ctx["ship_speed"].get(ship["ship"], 150.0)))
	return speed if speed < INF else 150.0
