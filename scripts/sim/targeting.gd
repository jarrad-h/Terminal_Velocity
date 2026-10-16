class_name Targeting
extends RefCounted
## C8: pure target selection over candidate positions.


## Index of the closest position to `origin`, or -1 if there are none.
static func nearest(origin: Vector2, positions: Array[Vector2]) -> int:
	var best: int = -1
	var best_d2: float = INF
	for i: int in positions.size():
		var d2: float = origin.distance_squared_to(positions[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	return best


## Next index after `current` in nearest-first order, wrapping round.
## If `current` is -1 (no target), returns the nearest.
static func cycle(origin: Vector2, positions: Array[Vector2], current: int) -> int:
	if positions.is_empty():
		return -1
	var order: Array[int] = []
	for i: int in positions.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return origin.distance_squared_to(positions[a]) < origin.distance_squared_to(positions[b]))
	var at: int = order.find(current)
	if at == -1:
		return order[0]
	return order[(at + 1) % order.size()]
