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
	var ships: Array[Ship] = []
	var cooldown: float = 0.0


var system: SystemDef = null
## Debug: when false, no traffic spawns.
var enabled: bool = true
var _entries: Array[Entry] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## `fill`: spawn the full population inside the system now (system load).
func configure(p_system: SystemDef, fill: bool) -> void:
	var keep: Dictionary = {}
	if not fill:
		for entry: Entry in _entries:
			keep[entry.pool.id] = entry.ships
	clear_traffic(fill)
	system = p_system
	for t: Dictionary in system.traffic:
		var entry := Entry.new()
		entry.pool = DataRegistry.get_ai_pool(t["pool"])
		entry.count = t["count"]
		entry.ships.assign(keep.get(entry.pool.id, []))
		_entries.append(entry)
		if fill and enabled:
			for i: int in entry.count:
				_spawn(entry, "inside")


## Removes traffic (all spawned ships when `free_ships`, else just forgets them).
func clear_traffic(free_ships: bool = true) -> void:
	if free_ships:
		for entry: Entry in _entries:
			for ship: Ship in entry.ships:
				if is_instance_valid(ship):
					ship.remove_from_group(&"ships")
					ship.queue_free()
	_entries.clear()


func live_count() -> int:
	var n: int = 0
	for entry: Entry in _entries:
		n += entry.ships.size()
	return n


func _physics_process(delta: float) -> void:
	if system == null or not enabled:
		return
	for entry: Entry in _entries:
		# Disabled ships stay in space (boarding comes in M5) but no longer count.
		entry.ships = entry.ships.filter(func(ship: Ship) -> bool:
			return is_instance_valid(ship) and not ship.is_queued_for_deletion() and not ship.health.is_disabled)
		if entry.ships.size() >= entry.count:
			continue
		entry.cooldown -= delta
		if entry.cooldown <= 0.0:
			var from_planet: bool = entry.pool.spawn_from_planets and not _landable().is_empty() and _rng.randf() < 0.5
			_spawn(entry, "takeoff" if from_planet else "arrive")
			entry.cooldown = _rng.randf_range(system.respawn_delay.x, system.respawn_delay.y)


## D3: spawns one ship from `pool` at `at`, optionally under another
## government or with a fixed personality (tests).
func spawn_from_pool(pool: AiPoolDef, at: Vector2, government_override: String = "", personality_id: String = "") -> Ship:
	var personality: PersonalityDef = DataRegistry.get_personality(personality_id) if personality_id != "" else null
	return _make(pool, at, _rng.randf() * TAU, Vector2.ZERO, "inside", null, government_override, personality)


func _spawn(entry: Entry, mode: String) -> void:
	var at: Vector2
	var heading: float = _rng.randf() * TAU
	var velocity := Vector2.ZERO
	var start_planet: SystemObjectDef = null
	match mode:
		"takeoff":
			var planets: Array[SystemObjectDef] = _landable()
			start_planet = planets[_rng.randi() % planets.size()]
			at = start_planet.position
		"arrive":
			var dir: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
			at = dir * system.edge_radius
			heading = Aim.rotation_of(-dir)
			velocity = -dir * _ship_speed_hint(entry.pool) * 0.5
		_:
			at = _inside_point(entry.pool)
	var ship: Ship = _make(entry.pool, at, heading, velocity, mode, start_planet)
	if ship != null:
		entry.ships.append(ship)
		if mode == "arrive":
			Flash.spawn(ship.get_parent(), at, ship.hit_radius * 2.0, Color(0.6, 0.8, 1.0), 0.5)


func _make(pool: AiPoolDef, at: Vector2, heading: float, velocity: Vector2, mode: String, start_planet: SystemObjectDef,
		government_override: String = "", personality: PersonalityDef = null) -> Ship:
	var scene: Node = get_tree().get_first_node_in_group(&"system_scene")
	var ship_id: String = pool.ships[WeightedPick.pick(_weights(pool.ships), _rng.randf())]["ship"]
	var ship: Ship = scene.spawn_ship(ship_id, at, government_override if government_override != "" else pool.government)
	if ship == null:
		return null
	ship.place(at, heading, velocity.limit_length(ship.body.stats.top_speed))
	var controller := AIController.new()
	controller.setup(pool, personality if personality != null else _pick_personality(pool), system, mode, start_planet, _rng.randi())
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


func _ship_speed_hint(pool: AiPoolDef) -> float:
	var def: ShipDef = DataRegistry.get_ship(pool.ships[0]["ship"])
	return def.top_speed if def != null else 0.0


## A spot inside the system, kept out of sensor range (× 1.2) of the player so
## nothing opens fire the moment the system loads.
func _inside_point(pool: AiPoolDef) -> Vector2:
	var player: Ship = get_tree().get_first_node_in_group(&"player")
	var keep_away: float = pool.sensor_range * 1.2
	var at := Vector2.ZERO
	for attempt: int in 20:
		at = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.15, 0.7) * system.edge_radius
		if player == null or at.distance_to(player.global_position) > keep_away:
			break
	return at
