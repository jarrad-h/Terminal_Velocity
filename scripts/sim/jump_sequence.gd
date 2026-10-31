class_name JumpSequence
extends RefCounted
## TR2: the hyperspace jump, flown with the ship's own flight model while the
## player's controls are locked: stop (turn and burn against the velocity),
## turn to face the destination's bearing, count down, then accelerate past
## the speed cap (overdrive) until the hyperdrive engages. Pure: step() turns
## the ship's state into this frame's FlightInput, as a controller would.

enum Phase { STOPPING, ALIGNING, COUNTDOWN, OVERDRIVE, ENGAGED, CANCELLED }

var phase: Phase = Phase.STOPPING
## Unit direction of travel (origin → destination on the galaxy map).
var bearing: Vector2
var countdown_left: float
var stop_speed: float
var align_tolerance: float
var thrust_angle: float
var overdrive_accel: float
var engage_speed: float


## `settings`: game.json hyperspace; `stats`: the ship's normal flight stats.
func _init(p_bearing: Vector2, countdown: float, settings: Dictionary, stats: FlightStats) -> void:
	bearing = p_bearing.normalized()
	countdown_left = countdown
	stop_speed = float(settings["stop_speed"])
	align_tolerance = float(settings["align_tolerance"])
	thrust_angle = float(settings["thrust_angle"])
	overdrive_accel = stats.accel * float(settings["overdrive_accel_factor"])
	engage_speed = stats.top_speed * float(settings["engage_speed_factor"])


## One physics frame. Once slow enough to stop this frame, the ship is held
## still (`state.velocity` is zeroed) until overdrive.
func step(state: FlightState, stats: FlightStats, delta: float) -> FlightInput:
	match phase:
		Phase.STOPPING:
			if state.velocity.length() <= maxf(stop_speed, stats.accel * delta):
				state.velocity = Vector2.ZERO
				phase = Phase.ALIGNING
				return step(state, stats, delta)
			return Steering.toward_velocity(state, stats, Vector2.ZERO, thrust_angle, delta)
		Phase.ALIGNING:
			state.velocity = Vector2.ZERO
			if Steering.aligned(state.rotation, bearing, align_tolerance):
				phase = Phase.COUNTDOWN
			return Steering.face(state, stats, bearing, delta)
		Phase.COUNTDOWN:
			state.velocity = Vector2.ZERO
			countdown_left -= delta
			if countdown_left <= 0.0:
				countdown_left = 0.0
				phase = Phase.OVERDRIVE
			return Steering.face(state, stats, bearing, delta)
		Phase.OVERDRIVE:
			if state.velocity.length() >= engage_speed - 0.01:
				phase = Phase.ENGAGED
				return FlightInput.new()
			var input: FlightInput = Steering.face(state, stats, bearing, delta)
			input.thrust = true
			return input
	return FlightInput.new()


## The flight stats to fly with this frame: overdrive lifts the speed cap to
## the hyperdrive speed and boosts acceleration (and keeps it once engaged);
## otherwise the ship's own.
func flight_stats(base: FlightStats) -> FlightStats:
	if phase == Phase.OVERDRIVE or phase == Phase.ENGAGED:
		return FlightStats.new(overdrive_accel, engage_speed, base.turn_rate)
	return base


## A voluntary cancel (J, firing): refused once the countdown has ended
## and the ship is committed to the jump. Returns whether it cancelled.
func cancel() -> bool:
	if not can_cancel():
		return false
	phase = Phase.CANCELLED
	return true


## Being disabled stops the jump at any point before the hyperdrive engages.
func abort() -> void:
	if is_active():
		phase = Phase.CANCELLED


## TR2: the player can call the jump off until the countdown ends.
func can_cancel() -> bool:
	return phase == Phase.STOPPING or phase == Phase.ALIGNING or phase == Phase.COUNTDOWN


func is_active() -> bool:
	return phase != Phase.ENGAGED and phase != Phase.CANCELLED


func is_engaged() -> bool:
	return phase == Phase.ENGAGED


## HUD text for the current phase.
func label() -> String:
	match phase:
		Phase.STOPPING:
			return "Hyperspace: stopping"
		Phase.ALIGNING:
			return "Hyperspace: aligning"
		Phase.COUNTDOWN:
			return "Hyperspace in %.1f" % countdown_left
		Phase.OVERDRIVE:
			return "Hyperspace: engaging"
	return ""
