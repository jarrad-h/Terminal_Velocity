class_name Formation
extends RefCounted
## Fleet formations (PS4 playtest, 1 Nov 2026): where each follower flies
## relative to its leader. Offsets are in the leader's frame (ship faces up,
## -y; +x to starboard). Pure.

const TYPES: Array[String] = ["none", "wedge", "line"]


## Follower `slot` (1 = first follower) of a `type` formation, `spacing` px apart.
## wedge: alternating right and left, each pair a row further back.
## line: one behind another.
static func offset(slot: int, type: String, spacing: float) -> Vector2:
	if slot <= 0:
		return Vector2.ZERO
	match type:
		"wedge":
			var row: int = (slot + 1) / 2
			var side: float = 1.0 if slot % 2 == 1 else -1.0
			return Vector2(side * row * spacing, row * spacing)
		"line":
			return Vector2(0.0, slot * spacing)
	return Vector2.ZERO


## World position of a follower's slot behind a leader at `leader_position`
## facing `leader_rotation`.
static func slot_position(slot: int, type: String, spacing: float, leader_position: Vector2, leader_rotation: float) -> Vector2:
	return leader_position + offset(slot, type, spacing).rotated(leader_rotation)
