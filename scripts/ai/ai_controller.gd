class_name AIController
extends Node
## A1–A5, A7: drives an AI ship. Its group (AI pool + government) sets the
## role and who is friend or foe; its personality shades the decisions. It
## produces the same FlightInput as the player's controller, so the ship's
## flight model and weapons treat AI and player identically.
##
## Decisions run every ai.think_interval seconds; steering runs every frame.

enum State { TRAVEL, DOCKED, PATROL, ATTACK, FLEE, LEAVE, JUMPING }
const STATE_NAMES: Dictionary = {
	State.TRAVEL: "travelling", State.DOCKED: "docked", State.PATROL: "patrolling",
	State.ATTACK: "attacking", State.FLEE: "fleeing", State.LEAVE: "leaving",
	State.JUMPING: "jumping",
}

var pool: AiPoolDef
var personality: PersonalityDef
var system: SystemDef
var state: State = State.PATROL
var target: Ship = null
## Where TRAVEL, PATROL, LEAVE and edge-bound FLEE are heading.
var destination: Vector2 = Vector2.ZERO
## Planet for TRAVEL, DOCKED and planet-bound FLEE (null when heading elsewhere).
var planet: SystemObjectDef = null
## A9: the neighbouring system a leaving ship jumps to ("" = none known), and
## the map bearing towards it.
var exit_system: String = ""
var exit_bearing: Vector2 = Vector2.ZERO
## A10: this ship travels the gate network: it leaves by docking with the
## system's gate instead of jumping.
var via_gate: bool = false

var _stops_left: int = 0
var _timer: float = 0.0
var _think_left: float = 0.0
var _resume_state: State = State.PATROL
var _input: FlightInput = FlightInput.new()
var _rng := RandomNumberGenerator.new()
var _start: String = "inside"

@onready var ship: Ship = get_parent()


## `start`: "arrive" (jumped in at the edge), "takeoff" (from `start_planet`)
## or "inside" (already in the system when it loads). Call before adding the
## controller to the ship; the first state is chosen in _ready.
func setup(p_pool: AiPoolDef, p_personality: PersonalityDef, p_system: SystemDef, start: String, start_planet: SystemObjectDef = null, seed_value: int = 0) -> void:
	pool = p_pool
	personality = p_personality
	system = p_system
	_start = start
	planet = start_planet
	_rng.seed = seed_value if seed_value != 0 else randi()


func _ready() -> void:
	process_physics_priority = -10  # decide before the ship flies and fires
	ship.role = pool.behaviour
	ship.tolerance_factor = personality.tolerance_factor
	ship.attacked.connect(_on_attacked)
	DataRegistry.data_reloaded.connect(_on_data_reloaded)
	_stops_left = _rng.randi_range(pool.stops.x, pool.stops.y)
	_timer = _rng.randf_range(pool.stay_time.x, pool.stay_time.y)
	_think_left = _rng.randf() * _ai("think_interval")
	if pool.behaviour == "trader":
		if _start == "takeoff" and planet != null:
			_take_off()
		else:
			planet = null
			_travel_to_next_planet()
	else:
		_new_waypoint()
		state = State.PATROL


func get_flight_input() -> FlightInput:
	return _input


## D9 label: role/personality: state.
func get_state_label() -> String:
	var who: String = "%s/%s" % [pool.behaviour, personality.name.to_lower()]
	if state == State.ATTACK and is_instance_valid(target):
		return "%s: attacking %s" % [who, target.def.name]
	return "%s: %s" % [who, STATE_NAMES[state]]


func _physics_process(delta: float) -> void:
	if state == State.JUMPING:
		_update_jump()
		return
	if DebugCommands.ai_paused or not ship.can_act():
		_input = FlightInput.new()
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = _ai("think_interval")
		_think(_ai("think_interval"))
	_steer(delta)


# --- Decisions ---------------------------------------------------------------

func _think(elapsed: float) -> void:
	if state == State.DOCKED:
		_timer -= elapsed
		if _timer <= 0.0:
			_take_off()
		return
	if state == State.ATTACK and (not _valid_target(target) or not ship.is_hostile_to(target)):
		_end_attack()
	if state == State.ATTACK and ship.global_position.distance_to(target.global_position) > pool.sensor_range * _ai("disengage_factor"):
		_end_attack()
	if state != State.FLEE and state != State.LEAVE:
		# A4: retreat below the (personality-shifted) shield threshold.
		if Behaviour.should_flee(ship.health.shield, ship.health.max_shield, _flee_threshold()):
			_start_flee()
			return
		# A2, A3, A5, A7: start a fight if this ship does that and the odds allow.
		if state != State.ATTACK and Behaviour.starts_fights(pool.behaviour, personality.starts_fights) and _armed():
			var enemy: Ship = _nearest_enemy()
			if enemy != null and _odds_ok():
				_start_attack(enemy)
				return
	match state:
		State.PATROL:
			_timer -= elapsed
			if _timer <= 0.0:
				_start_leave()
			elif ship.global_position.distance_to(destination) < pool.sensor_range * _ai("waypoint_reached_fraction"):
				_new_waypoint()
		State.LEAVE, State.FLEE:
			if planet == null and ship.global_position.length() >= system.jump_radius:
				_start_jump()


func _on_attacked(attacker: Ship) -> void:
	if state == State.FLEE or state == State.LEAVE or state == State.DOCKED or state == State.JUMPING:
		return
	if not ship.is_hostile_to(attacker) or not ship.can_act():
		return
	# A1, A7: fight back or run, by role and personality.
	if Behaviour.fights_back(pool.behaviour, personality.when_attacked) and _armed():
		if state != State.ATTACK:
			_start_attack(attacker)
	else:
		_start_flee()


func _start_attack(enemy: Ship) -> void:
	if state != State.ATTACK:
		_resume_state = state
	state = State.ATTACK
	target = enemy
	ship.set_target(enemy)


func _end_attack() -> void:
	target = null
	ship.set_target(null)
	state = _resume_state
	if state == State.PATROL:
		_new_waypoint()


## A4 / A1: traders run for the nearest landable planet; others for the edge.
func _start_flee() -> void:
	target = null
	ship.set_target(null)
	state = State.FLEE
	planet = _nearest_landable() if pool.behaviour == "trader" else null
	if planet == null:
		_pick_exit()


## C9 Assist: a recovered ship heads for the edge and leaves.
func depart() -> void:
	target = null
	ship.set_target(null)
	_start_leave()


func _start_leave() -> void:
	state = State.LEAVE
	planet = system.gate() if via_gate else null
	if planet == null:
		_pick_exit()


## A9: a real neighbouring system to leave for, and a point beyond the jump
## radius on its bearing; with no neighbours, straight out from the centre.
func _pick_exit() -> void:
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	var options: Array[String] = Hyperlanes.neighbours(galaxy, system.id) if galaxy != null and galaxy.has_system(system.id) else []
	if options.is_empty():
		exit_system = ""
		destination = _edge_point_away_from_centre()
		return
	exit_system = options[_rng.randi() % options.size()]
	exit_bearing = Hyperlanes.bearing(galaxy, system.id, exit_system)
	destination = exit_bearing * system.jump_radius * _ai("jump_out_factor")


## A9: beyond the jump radius, hand the ship to the same jump sequence the
## player flies (TR2); hits don't stop it, being disabled does.
func _start_jump() -> void:
	state = State.JUMPING
	target = null
	ship.set_target(null)
	var bearing: Vector2 = exit_bearing if exit_system != "" else ship.global_position.normalized()
	ship.autopilot = JumpSequence.new(bearing, ship.def.jump_countdown, DataRegistry.settings["hyperspace"], ship.body.stats)


func _update_jump() -> void:
	if ship.autopilot == null:
		return
	if not ship.can_act():
		ship.autopilot.abort()
		ship.autopilot = null
		state = State.FLEE
		return
	if ship.autopilot.is_engaged():
		ship.autopilot = null
		_jump_out()


func _travel_to_next_planet() -> void:
	var options: Array[SystemObjectDef] = _landable_planets()
	options.erase(planet)
	if options.is_empty():
		_start_leave()
		return
	planet = options[_rng.randi() % options.size()]
	state = State.TRAVEL


func _new_waypoint() -> void:
	# Warships patrol near the system's objects; pirates roam anywhere inside.
	if pool.behaviour == "warship" and not system.objects.is_empty() and _rng.randf() < _ai("object_patrol_chance"):
		var obj: SystemObjectDef = system.objects[_rng.randi() % system.objects.size()]
		destination = obj.position + Vector2.from_angle(_rng.randf() * TAU) * (obj.radius + pool.sensor_range * _ai("object_patrol_offset_factor"))
	else:
		var band: Vector2 = _ai_band("roam_band")
		destination = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(band.x, band.y) * system.edge_radius


func _land() -> void:
	if planet.type == "gate":
		_jump_out()  # A10: through the gate
		return
	var fleeing: bool = state == State.FLEE
	ship.place(planet.position, ship.rotation)
	ship.set_docked(true)
	if fleeing:
		_leave_quietly()  # ran home and stays there
		return
	_stops_left -= 1
	state = State.DOCKED
	_timer = _rng.randf_range(pool.dwell_time.x, pool.dwell_time.y)


func _take_off() -> void:
	ship.place(planet.position, _rng.randf() * TAU)
	ship.set_docked(false)
	if _stops_left > 0:
		_travel_to_next_planet()
	else:
		_start_leave()


## A6: job done; jump out with a flash.
func _jump_out() -> void:
	Flash.spawn(ship.get_parent(), ship.global_position, ship.hit_radius * 2.0, Color(0.6, 0.8, 1.0), 0.5)
	_leave_quietly()


func _leave_quietly() -> void:
	ship.remove_from_group(&"ships")
	ship.queue_free()


# --- Steering -----------------------------------------------------------------

func _steer(delta: float) -> void:
	var s: FlightState = ship.body.state
	var stats: FlightStats = ship.body.stats
	var thrust_angle: float = _ai("thrust_angle")
	match state:
		State.DOCKED:
			_input = FlightInput.new()
		State.ATTACK:
			_steer_attack(s, stats, delta)
		State.TRAVEL, State.FLEE, State.LEAVE when planet != null:
			_input = Steering.toward_velocity(s, stats, Steering.arrive_velocity(s, stats, planet.position), thrust_angle, delta)
			var landing: Dictionary = DataRegistry.settings["landing"]
			if PortRules.landing_check(s.position.distance_to(planet.position), planet.radius, float(landing["radius_fraction"]),
					s.velocity.length(), float(landing["max_speed"])) == "":
				_land()
		State.PATROL:
			_input = Steering.toward_velocity(s, stats, Steering.arrive_velocity(s, stats, destination), thrust_angle, delta)
		_:
			# LEAVE and edge-bound FLEE: full speed outward.
			var out: Vector2 = (destination - s.position).normalized() * stats.top_speed
			_input = Steering.toward_velocity(s, stats, out, thrust_angle, delta)


func _steer_attack(s: FlightState, stats: FlightStats, delta: float) -> void:
	if not _valid_target(target):
		_input = FlightInput.new()
		return
	var to_target: Vector2 = target.global_position - s.position
	var distance: float = to_target.length()
	var reach: float = ship.weapons.primary_range()
	var shot_speed: float = ship.weapons.primary_shot_speed()
	var aim: Vector2 = to_target.normalized()
	if shot_speed > 0.0:
		aim = Aim.intercept_direction(s.position, target.global_position, target.get_velocity() - s.velocity, shot_speed)
	_input = Steering.face(s, stats, aim, delta)
	_input.thrust = distance > reach * _ai("standoff_fraction") and Steering.aligned(s.rotation, to_target, _ai("thrust_angle"))
	var in_range: bool = distance <= reach
	_input.fire_primary = in_range and Steering.aligned(s.rotation, aim, pool.fire_angle + ship.weapons.tracking_slack())
	_input.fire_secondary = distance <= ship.weapons.guided_range()


# --- Queries -------------------------------------------------------------------

## Untyped on purpose: `other` may be a freed ship.
func _valid_target(other: Variant) -> bool:
	return is_instance_valid(other) and other is Ship and other.is_active() and not other.health.is_disabled


func _armed() -> bool:
	return not ship.weapons.mounts.is_empty()


func _nearest_enemy() -> Ship:
	var best: Ship = null
	var best_d2: float = pool.sensor_range * pool.sensor_range
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var other: Ship = node
		if not _valid_target(other) or not ship.is_hostile_to(other):
			continue
		var d2: float = ship.global_position.distance_squared_to(other.global_position)
		if d2 <= best_d2:
			best_d2 = d2
			best = other
	return best


## A5: friends (own government and allies) against everything hostile, within sensor range.
func _odds_ok() -> bool:
	var own: float = 0.0
	var enemy: float = 0.0
	var mine: GovernmentDef = ship.gov_def()
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var other: Ship = node
		if not _valid_target(other) or ship.global_position.distance_to(other.global_position) > pool.sensor_range:
			continue
		if other == ship or Relations.allied(mine, other.gov_def()):
			own += other.def.strength
		elif ship.is_hostile_to(other):
			enemy += other.def.strength
	var odds: float = Behaviour.max_odds(mine.max_odds if mine != null else 1.0, personality.odds_factor)
	return Relations.odds_ok(own, enemy, odds)


func _flee_threshold() -> float:
	var mine: GovernmentDef = ship.gov_def()
	return Behaviour.flee_threshold(mine.flee_shield_pct if mine != null else 0.0, personality.flee_shield_offset)


func _landable_planets() -> Array[SystemObjectDef]:
	var result: Array[SystemObjectDef] = []
	for obj: SystemObjectDef in system.objects:
		if obj.landable:
			result.append(obj)
	return result


func _nearest_landable() -> SystemObjectDef:
	var best: SystemObjectDef = null
	for obj: SystemObjectDef in _landable_planets():
		if best == null or ship.global_position.distance_squared_to(obj.position) < ship.global_position.distance_squared_to(best.position):
			best = obj
	return best


func _edge_point_away_from_centre() -> Vector2:
	var dir: Vector2 = ship.global_position.normalized()
	if dir.is_zero_approx():
		dir = Vector2.from_angle(_rng.randf() * TAU)
	return dir * system.jump_radius * _ai("jump_out_factor")


func _ai(key: String) -> float:
	return float(DataRegistry.settings["ai"][key])


func _ai_band(key: String) -> Vector2:
	var band: Array = DataRegistry.settings["ai"][key]
	return Vector2(band[0], band[1])


## D8: pick up retuned pool and personality definitions by ID.
func _on_data_reloaded() -> void:
	var fresh_pool: AiPoolDef = DataRegistry.get_ai_pool(pool.id)
	if fresh_pool != null:
		pool = fresh_pool
	if personality.id != "":
		var fresh: PersonalityDef = DataRegistry.get_personality(personality.id)
		if fresh != null:
			personality = fresh
			ship.tolerance_factor = personality.tolerance_factor
	var fresh_system: SystemDef = DataRegistry.get_system(system.id)
	if fresh_system != null:
		system = fresh_system
