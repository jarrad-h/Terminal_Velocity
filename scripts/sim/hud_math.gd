class_name HudMath
extends RefCounted
## H3: pure helpers for HUD readouts.


## Schematic fill for an armour fraction (0–1): `full` at 1, `half` at 0.5,
## `empty` at 0, blending linearly between.
static func health_colour(fraction: float, full: Color, half: Color, empty: Color) -> Color:
	var f: float = clampf(fraction, 0.0, 1.0)
	if f >= 0.5:
		return half.lerp(full, (f - 0.5) * 2.0)
	return empty.lerp(half, f * 2.0)


## Uniform scale that fits `size` inside `box` (never above `max_scale`).
static func fit_scale(size: Vector2, box: Vector2, max_scale: float) -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(minf(box.x / size.x, box.y / size.y), max_scale)
