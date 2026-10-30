class_name StarLight
extends RefCounted
## V7: how the system's star lights the player's surroundings. Pure.


## The star's colour blended towards white: 0 = white light, 1 = the star's
## own colour.
static func tinted(star_colour: Color, tint: float) -> Color:
	return Color.WHITE.lerp(Color(star_colour, 1.0), clampf(tint, 0.0, 1.0))


## Energy multiplier at `distance` from a star of `radius`: `near` at its
## edge (and inside), `far` at `far_radii` radii out and beyond, linear between.
static func energy_factor(distance: float, radius: float, near: float, far: float, far_radii: float) -> float:
	var radii: float = distance / maxf(radius, 1.0)
	var t: float = clampf((radii - 1.0) / maxf(far_radii - 1.0, 0.001), 0.0, 1.0)
	return lerpf(near, far, t)


## Glare 0–1: 0 from `start_radii` radii out, rising smoothly to 1 at the
## star's edge; inside the star it stays 1 (lit all over, no shadow side).
static func glare(distance: float, radius: float, start_radii: float) -> float:
	var radii: float = distance / maxf(radius, 1.0)
	return 1.0 - smoothstep(1.0, maxf(start_radii, 1.001), radii)
