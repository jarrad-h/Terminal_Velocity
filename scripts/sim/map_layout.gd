class_name MapLayout
extends RefCounted
## TR7: placing the galaxy map and the system view on screen. Pure.


## Transform that fits `points` inside `rect` with `margin` px to spare,
## keeping the aspect ratio and centring them.
static func fit(points: Array[Vector2], rect: Rect2, margin: float) -> Transform2D:
	if points.is_empty():
		return Transform2D(0.0, rect.get_center())
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	var room: Vector2 = (rect.size - Vector2(margin, margin) * 2.0).max(Vector2.ONE)
	var span: Vector2 = bounds.size.max(Vector2(0.001, 0.001))
	var scale: float = minf(room.x / span.x, room.y / span.y)
	if bounds.size.x <= 0.001 and bounds.size.y <= 0.001:
		scale = 1.0
	var offset: Vector2 = rect.get_center() - bounds.get_center() * scale
	return Transform2D(0.0, Vector2(scale, scale), 0.0, offset)


## Index of the point nearest `at` within `radius`, or -1.
static func pick(points: Array[Vector2], at: Vector2, radius: float) -> int:
	var best: int = -1
	var best_d: float = radius * radius
	for i: int in points.size():
		var d: float = points[i].distance_squared_to(at)
		if d <= best_d:
			best_d = d
			best = i
	return best


## System view: px per world px so the system's furthest object (and its
## jump radius) fits inside `size` / 2.
static func system_scale(system: SystemDef, size: float) -> float:
	var extent: float = system.jump_radius
	for o: SystemObjectDef in system.objects:
		extent = maxf(extent, o.position.length() + o.radius)
	return size / 2.0 / maxf(extent, 1.0)
