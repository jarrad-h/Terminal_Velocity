class_name EntityPresence
extends Node
## PS4: persistent entities in the player's system as real ships.
## - On entering, each entity there materialises from its summary (damage
##   included). One that arrived the same day gets an arrival offset (seconds
##   from the player's entry, its data range or game.json's): already there
##   if negative, else it jumps in that long after the player, on the side
##   facing where it came from.
## - One due to leave today departs at a random point in the departure window,
##   by gate or hyperspace towards its next hop.
## - Its ships' state is written back when the player leaves or when all its
##   ships have left or been destroyed; the player damaging one gives a
##   grudge-holder its grudge.

var scene: Node  # SystemScene (no class_name)
## entity id -> {"ships": [Ship], "departed": [ship summaries], "arrive_in": float
## (seconds; < 0 = done), "depart_in": float (< 0 = not today)}
var _present: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Debug "traffic off" (D3): entities stay in the registry but don't appear.
var enabled: bool = true


func _ready() -> void:
	_rng.randomize()


## Called after the system loads (arrival, rescue, start).
func on_enter(system_id: String) -> void:
	_present.clear()
	if not enabled:
		return
	var today: int = GameState.clock.day
	var settings: Dictionary = DataRegistry.settings["entities"]
	for s: EntityState in GameState.entities.living_at(system_id):
		var def: PersistentEntityDef = DataRegistry.get_entity(s.id)
		if def == null or not GateRules.is_open(def.exists_if, GameState.flags):
			continue
		var entry: Dictionary = {"ships": [], "departed": [], "arrive_in": -1.0, "depart_in": -1.0}
		_present[s.id] = entry
		var offset: float = -1.0
		if s.arrived_day == today:
			var span: Vector2 = def.arrival_offset if def.has_arrival_offset else _range(settings["arrival_offset"])
			offset = _rng.randf_range(span.x, span.y)
		if offset > 0.0:
			entry["arrive_in"] = offset
		else:
			_materialise(s, def, false)
		if s.leave_day == today:
			var window: Vector2 = _range(settings["departure_window"])
			entry["depart_in"] = maxf(_rng.randf_range(window.x, window.y), offset + float(settings["min_stay_seconds"]))


## Called before the player leaves (jump, gate, rescue): write every present
## entity back to its summary.
func on_leave() -> void:
	for id: String in _present:
		_write_back(id)
	_present.clear()


## Debug: write entities back and remove their ships, or bring them back.
func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		on_leave()
	scene.refresh_entities()


func _physics_process(delta: float) -> void:
	for id: String in _present.keys():
		var entry: Dictionary = _present[id]
		var s: EntityState = GameState.entities.states.get(id)
		var def: PersistentEntityDef = DataRegistry.get_entity(id)
		if s == null or def == null:
			continue
		if entry["arrive_in"] > 0.0:
			entry["arrive_in"] -= delta
			if entry["arrive_in"] <= 0.0:
				_materialise(s, def, true)
		if entry["depart_in"] > 0.0 and entry["arrive_in"] <= 0.0:
			entry["depart_in"] -= delta
			if entry["depart_in"] <= 0.0:
				_depart(s, def)


## Ships for the entity's summary, in the system now (`arriving`: jumping in).
func _materialise(s: EntityState, def: PersistentEntityDef, arriving: bool) -> void:
	var entry: Dictionary = _present[s.id]
	var pool: AiPoolDef = DataRegistry.get_ai_pool(def.pool)
	var personality: PersonalityDef = DataRegistry.get_personality(def.personality) if def.personality != "" else null
	var system: SystemDef = scene.system
	var side: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	if s.came_from != "" and galaxy.has_system(s.came_from) and s.came_from != system.id:
		side = -Hyperlanes.bearing(galaxy, s.came_from, system.id)
	var centre: Vector2
	var gate: SystemObjectDef = system.gate()
	var by_gate: bool = arriving and s.came_via == "gate" and gate != null
	if by_gate:
		centre = gate.position + StellarArt.jump_point(gate)
	elif arriving:
		centre = side * system.jump_radius
	else:
		var band: Array = DataRegistry.settings["ai"]["inside_spawn_band"]
		centre = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(band[0], band[1]) * system.edge_radius
	var speed: float = 0.0 if by_gate else float(DataRegistry.settings["ai"]["arrival_speed_fraction"])
	var spacing: float = float(DataRegistry.settings["entities"]["ship_spacing"])
	var fleet: Fleet = null
	if def.formation != "none" and s.ships.size() > 1:
		fleet = Fleet.new()
		fleet.formation = def.formation
		fleet.spacing = float(DataRegistry.settings["entities"]["formation_spacing"])
	for i: int in s.ships.size():
		var summary: Dictionary = s.ships[i]
		var at: Vector2 = centre + side.orthogonal() * (i - (s.ships.size() - 1) / 2.0) * spacing
		var ship: Ship = scene.spawn_ship(summary["ship"], at, def.government)
		if ship == null:
			continue
		ship.callsign = def.name
		ship.set_meta("entity", s.id)
		var heading: float = Aim.rotation_of(-side) if arriving else _rng.randf() * TAU
		ship.place(at, heading, -side * ship.body.stats.top_speed * speed if arriving else Vector2.ZERO)
		var ai := AIController.new()
		ai.setup(pool, personality if personality != null else PersonalityDef.neutral(), system, "arrive" if arriving else "inside")
		ai.persistent = true
		ai.hunt_player = s.grudge_until >= GameState.clock.day
		ai.fleet = fleet
		ship.set_controller(ai)
		if arriving and not by_gate:
			ship.arrive_from_hyperspace(at, -side, ship.body.stats.top_speed * speed)  # after the controller: it clears autopilots
		if fleet != null:
			fleet.members.append(ship)
		_apply_summary(ship, summary)
		ship.attacked.connect(_on_attacked.bind(s.id))
		ship.tree_exiting.connect(_on_ship_gone.bind(s.id, ship))
		entry["ships"].append(ship)
		if arriving:
			Flash.spawn(ship.get_parent(), ship.global_position, ship.hit_radius * 2.0, Color(0.6, 0.8, 1.0), 0.5)


func _apply_summary(ship: Ship, summary: Dictionary) -> void:
	ship.health.shield = ship.health.max_shield * clampf(float(summary.get("shield", 1.0)), 0.0, 1.0)
	var hull: float = clampf(float(summary.get("hull", 1.0)), 0.0, 1.0)
	if hull <= ship.def.disable_armor_pct / 100.0:
		ship.health.force_disable()
	ship.health.armor = ship.health.max_armor * hull


## PS4: the entity leaves now, towards the next hop of its orders.
func _depart(s: EntityState, def: PersistentEntityDef) -> void:
	var ctx: Dictionary = GameState.entity_context()
	var from: String = s.location
	var today: int = GameState.clock.day
	for line: String in GameState.entities.depart(s, def, today, ctx):
		GameState.news.add(today, line)
	if not s.in_transit():
		return  # nowhere to go
	var hop: Array[Dictionary] = EntityRouting.plot(DataRegistry.galaxy(), from, s.transit_to, _speed(s),
		func(system_id: String) -> bool: return GameState.entity_may_use_gate(def, system_id))
	var by_gate: bool = not hop.is_empty() and hop[0]["via"] == "gate"
	var entry: Dictionary = _present[s.id]
	for ship: Variant in entry["ships"].duplicate():
		if not is_instance_valid(ship):
			continue
		if not (ship as Ship).can_act():
			# Disabled when its fleet moves on: abandoned, an ordinary wreck now (PS6).
			(ship as Ship).remove_meta("entity")
			entry["ships"].erase(ship)
		elif (ship as Ship).controller is AIController:
			((ship as Ship).controller as AIController).leave_for(s.transit_to, by_gate)


func _on_attacked(attacker: Ship, id: String) -> void:
	if attacker != null and is_instance_valid(attacker) and attacker.is_player():
		var def: PersistentEntityDef = DataRegistry.get_entity(id)
		var s: EntityState = GameState.entities.states.get(id)
		if def != null and s != null and def.grudge_days > 0 and s.grudge_until < GameState.clock.day + def.grudge_days:
			GameState.entities.give_grudge(id, def, GameState.clock.day)
			for ship: Variant in _present.get(id, {}).get("ships", []):
				if is_instance_valid(ship) and (ship as Ship).controller is AIController:
					((ship as Ship).controller as AIController).hunt_player = true


## A ship left the scene: jumped out (keep its state for the summary) or
## destroyed (lost). With none left here, write the entity back.
func _on_ship_gone(id: String, ship: Ship) -> void:
	# Ships from an earlier visit (freed as the system was rebuilt) leave the
	# tree after the new visit has started: they aren't part of it.
	if not _present.has(id) or not (_present[id]["ships"] as Array).has(ship):
		return
	var entry: Dictionary = _present[id]
	entry["ships"].erase(ship)
	if not ship.health.is_destroyed:
		entry["departed"].append(_summary(ship))  # jumped out or removed: not a loss
	if entry["ships"].is_empty() and entry["arrive_in"] <= 0.0:
		_write_back(id)
		_present.erase(id)


func _write_back(id: String) -> void:
	var entry: Dictionary = _present[id]
	if entry["arrive_in"] > 0.0:
		return  # never arrived while the player was here
	var ships: Array = entry["departed"].duplicate(true)
	for ship: Variant in entry["ships"]:
		if is_instance_valid(ship) and not (ship as Ship).health.is_destroyed:
			ships.append(_summary(ship))
	GameState.entities.write_back(id, ships)
	var s: EntityState = GameState.entities.states.get(id)
	var def: PersistentEntityDef = DataRegistry.get_entity(id)
	if s != null and not s.alive and def != null:
		GameState.news.add(GameState.clock.day, "%s was destroyed at %s" % [def.name, Hyperspace.system_name(GameState.travel.current_system)])


static func _summary(ship: Ship) -> Dictionary:
	return {"ship": ship.def.id, "hull": ship.health.armor / maxf(ship.health.max_armor, 0.001),
		"shield": ship.health.shield / maxf(ship.health.max_shield, 0.001)}


func _speed(s: EntityState) -> float:
	var speed: float = INF
	for ship: Dictionary in s.ships:
		var def: ShipDef = DataRegistry.get_ship(ship["ship"])
		if def != null:
			speed = minf(speed, def.jump_speed)
	return speed if speed < INF else 150.0


static func _range(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
