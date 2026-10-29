class_name Capsule
extends RefCounted
## V2: capsule hull maths. A hull is a capsule of `size` [width, length]
## (width ≤ length) running along the heading, centred at `offset` from the
## ship centre (ship space, facing up). Rotation convention as FlightModel.


## World endpoints of the capsule's core segment.
static func segment(position: Vector2, rotation: float, size: Vector2, offset: Vector2) -> PackedVector2Array:
	var centre: Vector2 = position + offset.rotated(rotation)
	var half: Vector2 = FlightModel.heading(rotation) * maxf(size.y - size.x, 0.0) / 2.0
	return PackedVector2Array([centre - half, centre + half])


## Edge-to-edge distance between two hulls (negative when they overlap).
static func gap(a_position: Vector2, a_rotation: float, a_size: Vector2, a_offset: Vector2,
		b_position: Vector2, b_rotation: float, b_size: Vector2, b_offset: Vector2) -> float:
	var a: PackedVector2Array = segment(a_position, a_rotation, a_size, a_offset)
	var b: PackedVector2Array = segment(b_position, b_rotation, b_size, b_offset)
	var closest: PackedVector2Array = Geometry2D.get_closest_points_between_segments(a[0], a[1], b[0], b[1])
	return closest[0].distance_to(closest[1]) - a_size.x / 2.0 - b_size.x / 2.0
