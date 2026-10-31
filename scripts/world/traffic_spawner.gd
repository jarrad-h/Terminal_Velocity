class_name TrafficSpawner
extends Node
## A6: keeps each of the system's traffic entries at its target count. When
## the system loads, ships start inside it; replacements arrive at the system
## edge or take off from a landable planet after the system's respawn_delay.
## Every ship gets a personality picked by weight from its AI pool (A7).

## One per system traffic entry.
class Entry:
	var pool: AiPoolDef
	var count: int
	## A10: "gate" traffic arrives and leaves through the system's gate.
	var via: String = "hyperspace"
	## Every live ship from this entry, disabled ones included (so they can be
	## freed on clear); only non-disabled ones count towards `count`.
	var ships: Array = []
	var cooldown: float = 0.0

	func prune() -> void:
		ships = ships.filter(func(ship: Variant) -> bool: return is_instance_valid(ship) and not ship.is_queued_for_deletion())

	func active_count() -> int:
		return ships.filter(func(ship: Variant) -> bool: return not ship.health.is_disabled).size()


var system: SystemDef = null
## Debug: when false, no traffic spawns.
var enabled: bool = true
var _entries: Array[Entry] = []
## D3 debug pool spawns: not part of the population, but freed with the system.
var _extras: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## `fill`: spawn the full population inside the system now (system load).
func configure(p_system: SystemDef, fill: bool) -> void:
	# Hot reload / same system: keep each entry's ships and respawn cooldown.
	var keep: Dictionary = {}
	if not fill:
		for entry: Entry in _entries:
			entry.prune()
			keep[entry.pool.id] = entry
	clear_traffic(fill)
	system = p_system
	for t: Dictionary in system.traffic:
		var entry := Entry.new()
		entry.pool = DataRegistry.get_ai_pool(t["pool"])
		entry.count = t["count"]
		if t["memory"] != "":
			# PS6: the system's memory shifts the population (more patrols on alert…).
			var rule: Dictionary = GameState.memory_rule(system.id, t["memory"])
			entry.count = SystemMemory.scaled_count(entry.count, GameState.memory_value(system.id, t["memory"]),
				float(rule["baseline"]), float(t["per_point"]))
		entry.via = t["via"]
		var old_entry: Entry = keep.get(entry.pool.id)
		if old_entry != null:
			entry.ships.assign(old_entry.ships)
			entry.cooldown = old_entry.cooldown
		else:
			entry.cooldown = _respawn_roll()
		_entries.append(entry)
		if fill and enabled:
			for i: int in entry.count:
				_spawn(entry, "inside")


## Removes traffic (all spawned ships when `free_ships`, else just forgets them).
func clear_traffic(free_ships: bool = true) -> void:
	if free_ships:
		for entry: Entry in _entries:
			entry.prune()
			for ship: Variant in entry.ships:
				ship.remove_from_group(&"ships")
				ship.queue_free()
		# Debug pool spawns (D3) belong to the system too.
		for ship: Variant in _extras:
			if is_instance_valid(ship) and not ship.is_queued_for_deletion():
				ship.remove_from_group(&"ships")
				ship.queue_free()
		_extras.clear()
	_entries.clear()


## PS6: the population an entry aims for this visit (after system memory).
func target_count(pool_id: String) -> int:
	for entry: Entry in _entries:
		if entry.pool.id == pool_id:
			return entry.count
	return -1


## Ships counting towards the population (not disabled).
func live_count() -> int:
	var n: int = 0
	for entry: Entry in _entries:
		entry.prune()
		n += entry.active_count()
	return n


func _physics_process(delta: float) -> void:
	if system == null or not enabled:
		return
	for entry: Entry in _entries:
		# Disabled ships stay in space (boarding comes in M5) but no longer count.
		entry.prune()
		if entry.active_count() >= entry.count:
			continue
		entry.cooldown -= delta
		if entry.cooldown <= 0.0:
			var from_planet: bool = entry.pool.spawn_from_planets and not _landable().is_empty() \
				and _rng.randf() < _ai("planet_spawn_chance")
			if entry.via == "gate" and _gate_open():
				_spawn(entry, "gate")
			elif entry.via == "gate":
				_spawn(entry, "arrive")  # gate closed (TR6): they come by hyperspace
			else:
				_spawn(entry, "takeoff" if from_planet else "arrive")
			entry.cooldown = _respawn_roll()


## D3: spawns one ship from `pool` at `at`, optionally under another
## government or with a fixed personality (tests).
func spawn_from_pool(pool: AiPoolDef, at: Vector2, government_override: String = "", personality_id: String = "") -> Ship:
	var personality: PersonalityDef = DataRegistry.get_personality(personality_id) if personality_id != "" else null
	var ship: Ship = _make(pool, at, _rng.randf() * TAU, Vector2.ZERO, 0.0, "inside", null, government_override, personality)
	if ship != null:
		_extras = _extras.filter(func(other: Variant) -> bool: return is_instance_valid(other))
		_extras.append(ship)
	return ship


func _spawn(entry: Entry, mode: String) -> void:
	var at: Vector2
	var heading: float = _rng.randf() * TAU
	var direction := Vector2.ZERO
	var speed_fraction: float = 0.0
	var start_planet: SystemObjectDef = null
	match mode:
		"takeoff":
			var planets: Array[SystemObjectDef] = _landable()
			start_planet = planets[_rng.randi() % planets.size()]
			at = start_planet.position
		"gate":
			# A10: out of the gate's field, stopped.
			var gate: SystemObjectDef = system.gate()
			at = gate.position + StellarArt.jump_point(gate)
		"arrive":
			# A9: in from a real neighbour, at the jump radius on its side (TR4).
			var dir: Vector2 = arrival_side()
			at = dir * system.jump_radius
			heading = Aim.rotation_of(-dir)
			direction = -dir
			speed_fraction = _ai("arrival_speed_fraction")
		_:
			at = _inside_point(entry.pool)
	var ship: Ship = _make(entry.pool, at, heading, direction, speed_fraction, mode, start_planet, "", null, entry.via == "gate")
	if ship != null:
		entry.ships.append(ship)
		if mode == "arrive" or mode == "gate":
			Flash.spawn(ship.get_parent(), at, ship.hit_radius * 2.0, Color(0.6, 0.8, 1.0), 0.5)


func _gate_open() -> bool:
	var gate: SystemObjectDef = system.gate()
	return gate != null and GateRules.is_open(gate.open_condition, GameState.flags)


## A9: unit vector from the centre to where an arriving ship appears: the
## side facing a random neighbouring system (any direction if none).
func arrival_side() -> Vector2:
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var options: Array[String] = Hyperlanes.neighbours(galaxy, system.id) if galaxy != null and galaxy.has_system(system.id) else []
	if options.is_empty():
		return Vector2.from_angle(_rng.randf() * TAU)
	var origin: String = options[_rng.randi() % options.size()]
	return -Hyperlanes.bearing(galaxy, origin, system.id)


## Spawns one gate arrival of `pool` now (A10; tests).
func spawn_gate_arrival(pool: AiPoolDef) -> Ship:
	var entry := Entry.new()
	entry.pool = pool
	entry.via = "gate"
	_spawn(entry, "gate")
	return entry.ships[0] if not entry.ships.is_empty() else null


## Spawns one arrival of `pool` now (A9; also used by tests).
func spawn_arrival(pool: AiPoolDef) -> Ship:
	var entry := Entry.new()
	entry.pool = pool
	_spawn(entry, "arrive")
	return entry.ships[0] if not entry.ships.is_empty() else null


## `direction` × `speed_fraction` of the picked ship's top speed is its starting velocity.
func _make(pool: AiPoolDef, at: Vector2, heading: float, direction: Vector2, speed_fraction: float, mode: String, start_planet: SystemObjectDef,
		government_override: String = "", personality: PersonalityDef = null, via_gate: bool = false) -> Ship:
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var ship_id: String = pool.ships[WeightedPick.pick(_weights(pool.ships), _rng.randf())]["ship"]
	var ship: Ship = scene.spawn_ship(ship_id, at, government_override if government_override != "" else pool.government)
	if ship == null:
		return null
	ship.place(at, heading, direction * ship.body.stats.top_speed * speed_fraction)
	var controller := AIController.new()
	controller.setup(pool, personality if personality != null else _pick_personality(pool), system, mode, start_planet, _rng.randi())
	controller.via_gate = via_gate
	ship.set_controller(controller)
	return ship


func _pick_personality(pool: AiPoolDef) -> PersonalityDef:
	if pool.personalities.is_empty():
		return PersonalityDef.neutral()
	var id: String = pool.personalities[WeightedPick.pick(_weights(pool.personalities), _rng.randf())]["personality"]
	return DataRegistry.get_personality(id)


func _weights(list: Array[Dictionary]) -> Array[float]:
	var weights: Array[float] = []
	for item: Dictionary in list:
		weights.append(float(item["weight"]))
	return weights


func _landable() -> Array[SystemObjectDef]:
	var result: Array[SystemObjectDef] = []
	for obj: SystemObjectDef in system.objects:
		if obj.landable:
			result.append(obj)
	return result



## A spot inside the system (ai.inside_spawn_band × edge radius), kept out of
## sensor range × ai.spawn_keep_away_factor of the player so nothing opens
## fire the moment the system loads.
func _inside_point(pool: AiPoolDef) -> Vector2:
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	var keep_away: float = pool.sensor_range * _ai("spawn_keep_away_factor")
	var band: Array = DataRegistry.settings["ai"]["inside_spawn_band"]
	var at := Vector2.ZERO
	for attempt: int in 20:
		at = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(band[0], band[1]) * system.edge_radius
		if player == null or at.distance_to(player.global_position) > keep_away:
			break
	return at


func _ai(key: String) -> float:
	return float(DataRegistry.settings["ai"][key])


## A6: seconds before the next replacement (system respawn_delay).
func _respawn_roll() -> float:
	return _rng.randf_range(system.respawn_delay.x, system.respawn_delay.y)
