class_name Fleet
extends RefCounted
## A persistent entity's ships flying as one force (PS4, playtest 1 Nov
## 2026): the first able ship leads with its normal behaviour; the others hold
## formation slots behind it. Whichever member is attacked, the whole fleet
## fights or flees together; when the leader jumps, everyone jumps.

var members: Array = []  # Ship (may be freed)
var formation: String = "wedge"
var spacing: float = 180.0


## The ship leading now: the first member still able to act (docked counts).
func leader() -> Ship:
	for ship: Variant in members:
		if is_instance_valid(ship) and (ship as Ship).can_act():
			return ship
	return null


func is_follower(ship: Ship) -> bool:
	var lead: Ship = leader()
	return lead != null and lead != ship


## Where `ship` should fly now: its slot behind the current leader.
func slot_of(ship: Ship) -> Vector2:
	var lead: Ship = leader()
	var slot: int = 0
	for member: Variant in members:
		if not is_instance_valid(member) or not (member as Ship).can_act() or member == lead:
			continue
		slot += 1
		if member == ship:
			break
	return Formation.slot_position(slot, formation, spacing, lead.global_position, lead.global_rotation)


## A member was attacked and chose to fight: every member treats the attacker
## as an enemy and engages it (no hitting the wingmen for free).
func engage(attacker: Ship) -> void:
	for ship: Variant in members:
		if is_instance_valid(ship) and (ship as Ship).can_act() and (ship as Ship).controller is AIController:
			(ship as Ship).provoke(attacker)
			((ship as Ship).controller as AIController).join_attack(attacker)


## A member chose to run: the leader flees and the others keep formation.
func flee() -> void:
	var lead: Ship = leader()
	if lead != null and lead.controller is AIController:
		(lead.controller as AIController).join_flee()


## The leader is jumping out: every able member jumps on the same bearing.
func jump_with(lead: Ship, bearing: Vector2) -> void:
	for ship: Variant in members:
		if ship != lead and is_instance_valid(ship) and (ship as Ship).can_act() and (ship as Ship).controller is AIController:
			((ship as Ship).controller as AIController).jump_now(bearing)
