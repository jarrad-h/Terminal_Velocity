class_name AIController
extends Node
## A1–A5, A7: drives an AI ship. Its group (AI pool + government) sets the
## role and who is friend or foe; its personality shades the decisions. It
## produces the same FlightInput as the player's controller, so the ship's
## flight model and weapons treat AI and player identically.
##
## Decisions run every ai.think_interval seconds; steering runs every frame.

## A11: a ship that has sheltered at a planet is done waiting (the threat has
## gone, or it's running the blockade); a persistent entity departs early.
signal shelter_ended

enum State { TRAVEL, DOCKED, PATROL, ATTACK, FLEE, LEAVE, JUMPING, ORBIT }
const STATE_NAMES: Dictionary = {
	State.TRAVEL: "travelling", State.DOCKED: "docked", State.PATROL: "patrolling",
	State.ATTACK: "attacking", State.FLEE: "fleeing", State.LEAVE: "leaving",
	State.JUMPING: "jumping", State.ORBIT: "in orbit",
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
## PS4: a persistent entity's ship: it only leaves when its entity departs
## (leave_for), never on its own stay timer or after its last stop.
var persistent: bool = false
## PS2: an entity holding a grudge hunts the player across the whole system,
## not just within sensor range.
var hunt_player: bool = false
## PS4: the entity's fleet this ship flies in (null = flies alone).
var fleet: Fleet = null
## PS4: a follower out of position, flying back to its slot.
var _regrouping: bool = false
## A11: holding over a planet (ORBIT) before docking (`_orbit_landing`) or
## after launching; then `_after_orbit` runs.
var _orbit_landing: bool = false
var _orbit_left: float = 0.0
var _after_orbit: Callable = Callable()
## A11: dock to shelter (it fled here); sheltering while docked; seconds the
## coast has been clear.
var _shelter_next: bool = false
var _sheltering: bool = false
var _clear_for: float = 0.0
## A11: a follower flying down to land with its leader.
var _landing_with_leader: bool = false
## A12: it has been attacked, so it returns covering fire at `_cover_target`.
var _under_fire: bool = false
var _cover_target: Ship = null

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


## Running from a fight: fleeing, landing to shelter, or sheltering (A1, A11).
func is_fleeing() -> bool:
	return state == State.FLEE or (state == State.ORBIT and _orbit_landing and _shelter_next) or (state == State.DOCKED and _sheltering)


func get_flight_input() -> FlightInput:
	return _input


## D9 label: role/personality: state.
func get_state_label() -> String:
	var who: String = "%s/%s" % [pool.behaviour, personality.name.to_lower()]
	if state == State.ATTACK and is_instance_valid(target):
		return "%s: attacking %s" % [who, target.def.name]
	return "%s: %s" % [who, STATE_NAMES[state]]


func _physics_process(delta: float) -> void:
	if DebugCommands.ai_paused:
		_input = FlightInput.new()
		return
	if state == State.JUMPING:
		_update_jump()
		return
	if not ship.can_act():
		_input = FlightInput.new()
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = _ai("think_interval")
		_think(_ai("think_interval"))
	_steer(delta)
	_covering_fire()


# --- Decisions ---------------------------------------------------------------

func _think(elapsed: float) -> void:
	_update_cover()
	if state == State.ORBIT:
		_orbit_left -= elapsed
		if _orbit_left <= 0.0:
			var next: Callable = _after_orbit
			_after_orbit = Callable()
			if next.is_valid():
				next.call()
		return
	if state == State.DOCKED:
		if _is_follower():
			return  # A11: launches with its leader
		if _sheltering:
			_shelter(elapsed)
			return
		_timer -= elapsed
		if _timer <= 0.0:
			_take_off()
		return
	if state == State.ATTACK and (not _valid_target(target) or not ship.is_hostile_to(target)):
		_end_attack()
	if state == State.ATTACK and ship.global_position.distance_to(target.global_position) > pool.sensor_range * _ai("disengage_factor") \
			and not (hunt_player and target.is_player()):
		_end_attack()
	if _is_follower() and state != State.ATTACK:
		return  # formation (or landing with the leader): the leader decides (fights and flights come via the fleet)
	if hunt_player and state in [State.PATROL, State.TRAVEL]:
		var player: Ship = get_tree().get_first_node_in_group(&"player")
		if _valid_target(player) and _armed():
			_attack_with_fleet(player)
			return
	if state != State.FLEE and state != State.LEAVE:
		# A4: retreat below the (personality-shifted) shield threshold.
		if Behaviour.should_flee(ship.health.shield, ship.health.max_shield, _flee_threshold()):
			_start_flee()
			return
		# A2, A3, A5, A7: start a fight if this ship does that and the odds allow.
		if state != State.ATTACK and Behaviour.starts_fights(pool.behaviour, personality.starts_fights) and _armed():
			var enemy: Ship = _nearest_enemy()
			if enemy != null and _odds_ok():
				_attack_with_fleet(enemy)
				return
	match state:
		State.PATROL:
			_timer -= elapsed
			if _timer <= 0.0 and not persistent:
				_start_leave()
			elif ship.global_position.distance_to(destination) < pool.sensor_range * _ai("waypoint_reached_fraction"):
				_new_waypoint()
		State.LEAVE, State.FLEE:
			if planet == null and ship.global_position.length() >= system.jump_radius:
				_start_jump()


func _on_attacked(attacker: Ship) -> void:
	_under_fire = true  # A12
	if state == State.FLEE or state == State.LEAVE or state == State.DOCKED or state == State.JUMPING:
		return
	if state == State.ORBIT and not _orbit_landing:
		return  # A11: launching; it reacts once under way (no diving back to shelter)
	if not ship.is_hostile_to(attacker) or not ship.can_act():
		return
	if state == State.ORBIT and _orbit_landing:
		_shelter_next = true  # A11: nearly down; shelter once docked
		if fleet != null:
			fleet.flee(attacker)
		return
	# A1, A7: fight back or run, by role and personality; in a fleet, every
	# member follows that choice, whichever member was hit.
	if Behaviour.fights_back(pool.behaviour, personality.when_attacked) and _armed():
		if fleet != null:
			fleet.engage(attacker)
		elif state != State.ATTACK:
			_start_attack(attacker)
	elif fleet != null:
		fleet.flee(attacker)
	else:
		_start_flee()


## A12: who to return fire at while not attacking: the last ship to hit it
## if still hostile and in range, else the nearest hostile ship in range.
func _update_cover() -> void:
	if not _under_fire or state == State.ATTACK:
		return
	var reach: float = maxf(ship.weapons.primary_range(), ship.weapons.guided_range())
	var best: Ship = null
	if state != State.DOCKED and state != State.JUMPING and reach > 0.0:
		var last: Ship = ship.last_attacker()
		if _cover_ok(last, reach):
			best = last
		else:
			for node: Node in get_tree().get_nodes_in_group(&"ships"):
				var other: Ship = node as Ship
				if _cover_ok(other, reach) and (best == null or ship.global_position.distance_squared_to(other.global_position) < ship.global_position.distance_squared_to(best.global_position)):
					best = other
	_cover_target = best
	if best != ship.get_target():
		ship.set_target(best)


func _cover_ok(other: Ship, reach: float) -> bool:
	return other != null and is_instance_valid(other) and other != ship and other.can_act() and not other.docked \
		and ship.is_hostile_to(other) and ship.global_position.distance_to(other.global_position) <= reach


## A12: covering fire this frame (steering is already decided and unchanged).
func _covering_fire() -> void:
	if state == State.ATTACK or state == State.DOCKED or state == State.JUMPING or not _valid_target(_cover_target):
		return
	var distance: float = ship.global_position.distance_to(_cover_target.global_position)
	_input.fire_primary = distance <= ship.weapons.primary_range()
	_input.fire_secondary = distance <= ship.weapons.guided_range()
	_input.covering_angle = pool.fire_angle


func _attack_with_fleet(enemy: Ship) -> void:
	if fleet != null:
		fleet.engage(enemy)
	else:
		_start_attack(enemy)


func _is_follower() -> bool:
	return fleet != null and fleet.is_follower(ship)


## Fleet: engage `attacker` with the rest of the fleet.
func join_attack(attacker: Ship) -> void:
	if state in [State.JUMPING, State.DOCKED, State.FLEE, State.LEAVE, State.ORBIT] or not _armed():
		return
	if state != State.ATTACK or target != attacker:
		_start_attack(attacker)


## Fleet: the leader runs (the others keep formation).
func join_flee() -> void:
	if state == State.ORBIT:
		if _orbit_landing:
			_shelter_next = true  # already landing: shelter there
	elif state == State.DOCKED:
		if not _sheltering:
			_start_sheltering()  # A11: down already: shelter instead of relaunching
	elif state not in [State.FLEE, State.LEAVE, State.JUMPING]:
		_start_flee()


## A11 fleet: the leader is landing at `p`; fly down and land too.
func land_at(p: SystemObjectDef) -> void:
	if state in [State.ATTACK, State.JUMPING, State.LEAVE, State.DOCKED, State.ORBIT] or p == null:
		return
	planet = p
	state = State.TRAVEL
	_landing_with_leader = true


## A11 fleet: the leader is launching; launch too (or stop flying down).
func launch_with_leader() -> void:
	if ship.docked:
		_launch(_rejoin)
	elif state == State.ATTACK:
		_landing_with_leader = false  # keep fighting; formation after
	elif _landing_with_leader or (state == State.ORBIT and _orbit_landing):
		_rejoin()


## A11: back in the fleet after landing with it.
func _rejoin() -> void:
	_landing_with_leader = false
	_sheltering = false
	if pool.behaviour == "trader":
		_travel_to_next_planet()
	else:
		_new_waypoint()
		state = State.PATROL


## Fleet: the leader is jumping; jump on the same bearing now.
func jump_now(bearing: Vector2) -> void:
	if state == State.JUMPING:
		return
	exit_bearing = bearing
	exit_system = "(fleet)"
	_start_jump()


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
	planet = _open_gate() if via_gate else null
	if planet == null:
		_pick_exit()


## A10, TR6: the system's gate if it's open, else null.
func _open_gate() -> SystemObjectDef:
	var gate: SystemObjectDef = system.gate()
	return gate if gate != null and GateRules.is_open(gate.open_condition, GameState.flags) else null


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
	var outward: Vector2 = ship.global_position.normalized()
	if state == State.FLEE and not outward.is_zero_approx():
		# Fleeing: the neighbour whose side of the system the ship is already on.
		for option: String in options:
			if Hyperlanes.bearing(galaxy, system.id, option).dot(outward) > Hyperlanes.bearing(galaxy, system.id, exit_system).dot(outward):
				exit_system = option
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
	if fleet != null and fleet.leader() == ship:
		fleet.jump_with(ship, bearing)  # the fleet jumps together


func _update_jump() -> void:
	if ship.autopilot == null:
		_start_flee()
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
		if _open_gate() != null:
			_jump_out()  # A10: through the gate
		else:
			via_gate = false  # closed while on the way (TR6): leave by hyperspace
			_start_leave()
		return
	# A11: hold over the planet, visible and targetable, then dock.
	_shelter_next = state == State.FLEE
	state = State.ORBIT
	_orbit_landing = true
	_orbit_left = _ai("orbit_pause")
	_after_orbit = _dock
	if fleet != null and fleet.leader() == ship:
		fleet.land_with(ship, planet)


func _dock() -> void:
	ship.place(planet.position, ship.rotation)
	ship.set_docked(true)
	state = State.DOCKED
	_landing_with_leader = false
	if _shelter_next:
		_start_sheltering()  # A11: it fled here
		return
	_stops_left -= 1
	_timer = _rng.randf_range(pool.dwell_time.x, pool.dwell_time.y)


func _take_off() -> void:
	_launch(func() -> void:
		if _stops_left > 0 or persistent:
			_travel_to_next_planet()
		else:
			_start_leave())


## A11: appear over the planet, hold there, then `after`.
func _launch(after: Callable) -> void:
	ship.place(planet.position, _rng.randf() * TAU)
	ship.set_docked(false)
	_sheltering = false
	state = State.ORBIT
	_orbit_landing = false
	_orbit_left = _ai("orbit_pause")
	_after_orbit = after
	if fleet != null and fleet.leader() == ship:
		fleet.launch_with(ship)


## A11: shelter until the threat goes, or run for it.
func _start_sheltering() -> void:
	_shelter_next = false
	_sheltering = true
	_clear_for = 0.0
	_timer = _rng.randf_range(pool.shelter_time.x, pool.shelter_time.y)


## A11: sheltering at a planet. Clear of hostile ships for long enough: run
## for safety elsewhere; shelter time up with the threat still there: run the
## blockade. Either way it leaves (an entity departs early, via its signal).
func _shelter(elapsed: float) -> void:
	if _threat_near():
		_clear_for = 0.0
		_timer -= elapsed
		if _timer > 0.0:
			return
	else:
		_clear_for += elapsed
		if _clear_for < _ai("shelter_clear_time"):
			return
	_sheltering = false
	if persistent and not shelter_ended.get_connections().is_empty():
		shelter_ended.emit()  # the entity departs (leave_for launches it)
		if ship.docked and state == State.DOCKED:
			_take_off()  # nowhere to go: carry on here
		return
	_launch(_start_leave)


## A11: a ship this one treats as hostile, able to act, within sensor range
## of the planet it's sheltering at.
func _threat_near() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var other: Ship = node as Ship
		if other != null and other != ship and other.can_act() and not other.docked and ship.is_hostile_to(other) \
				and other.global_position.distance_to(planet.position) <= pool.sensor_range:
			return true
	return false


## A6: job done; jump out with a flash.
## PS4: the entity is moving on: leave for `system_id`, by gate or by jump.
func leave_for(system_id: String, by_gate: bool) -> void:
	target = null
	ship.set_target(null)
	_sheltering = false
	if ship.docked:
		_launch(_leave_for.bind(system_id, by_gate))  # A11: launch, then go
		return
	_leave_for(system_id, by_gate)


func _leave_for(system_id: String, by_gate: bool) -> void:
	_landing_with_leader = false
	state = State.LEAVE
	via_gate = by_gate
	planet = _open_gate() if by_gate else null
	if planet != null:
		return
	var galaxy: GalaxyDef = DataRegistry.galaxy()
	if galaxy != null and galaxy.has_system(system_id) and galaxy.has_system(system.id) and system_id != system.id:
		exit_system = system_id
		exit_bearing = Hyperlanes.bearing(galaxy, system.id, system_id)
		destination = exit_bearing * system.jump_radius * _ai("jump_out_factor")
	else:
		_pick_exit()


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
	if _is_follower() and state not in [State.ATTACK, State.ORBIT, State.DOCKED] and not _landing_with_leader:
		_steer_formation(s, stats, thrust_angle, delta)
		return
	match state:
		State.DOCKED:
			_input = FlightInput.new()
		State.ORBIT:
			# A11: hold over the planet.
			_input = Steering.toward_velocity(s, stats, Steering.arrive_velocity(s, stats, planet.position), thrust_angle, delta, _deadband(stats))
		State.ATTACK:
			_steer_attack(s, stats, delta)
		State.TRAVEL, State.FLEE, State.LEAVE when planet != null:
			_input = Steering.toward_velocity(s, stats, _cruise(Steering.arrive_velocity(s, stats, planet.position), stats), thrust_angle, delta, _deadband(stats))
			var landing: Dictionary = DataRegistry.settings["landing"]
			if PortRules.landing_check(s.position.distance_to(planet.position), planet.radius, float(landing["radius_fraction"]),
					s.velocity.length(), float(landing["max_speed"])) == "":
				_land()
		State.PATROL:
			_input = Steering.toward_velocity(s, stats, _cruise(Steering.arrive_velocity(s, stats, destination), stats), thrust_angle, delta, _deadband(stats))
		_:
			# LEAVE and edge-bound FLEE: full speed outward.
			var out: Vector2 = (destination - s.position).normalized() * stats.top_speed
			_input = Steering.toward_velocity(s, stats, _cruise(out, stats), thrust_angle, delta, _deadband(stats))


## PS4: a fleet leader cruises below top speed so its wingmen (often the same
## hull) can keep station; fleeing, it goes flat out.
func _cruise(desired: Vector2, stats: FlightStats) -> Vector2:
	if fleet == null or state == State.FLEE or fleet.leader() != ship or fleet.members.size() < 2:
		return desired
	return desired.limit_length(stats.top_speed * float(DataRegistry.settings["entities"]["formation_cruise"]))


## PS4: hold this ship's slot behind the fleet leader (game.json
## entities.formation_*) without constant fussing. Near the slot it just faces
## the leader's heading and burns forward when falling behind; drift beyond
## `formation_hold` starts one proper manoeuvre back into the slot (turning
## round to brake if it must), which ends once settled there.
func _steer_formation(s: FlightState, stats: FlightStats, thrust_angle: float, delta: float) -> void:
	var lead: Ship = fleet.leader()
	var slot: Vector2 = fleet.slot_of(ship)
	var lead_velocity: Vector2 = lead.get_velocity() if not lead.docked else Vector2.ZERO
	var cfg: Dictionary = DataRegistry.settings["entities"]
	var off: float = s.position.distance_to(slot)
	var settle_speed: float = float(cfg["formation_settle_speed"])
	if off > float(cfg["formation_hold"]):
		_regrouping = true
	elif _regrouping and off < float(cfg["formation_settle"]) and (s.velocity - lead_velocity).length() < settle_speed:
		_regrouping = false
	if _regrouping:
		# Not fussing over errors smaller than the settle speed ends it cleanly.
		_input = Steering.toward_velocity(s, stats, Steering.arrive_velocity(s, stats, slot, lead_velocity), thrust_angle, delta, settle_speed * 0.8)
		return
	var heading: Vector2 = FlightModel.heading(lead.global_rotation)
	_input = Steering.face(s, stats, heading, delta)
	_input.thrust = (lead_velocity - s.velocity).dot(heading) > stats.accel * delta and Steering.aligned(s.rotation, heading, thrust_angle)


## Velocity error too small to turn round for (ai.steer_deadband × top speed).
func _deadband(stats: FlightStats) -> float:
	return stats.top_speed * _ai("steer_deadband")


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
