class_name SceneryGen
extends RefCounted
## L2/L3: deterministic scenery for one chunk. Each (system seed, chunk,
## scenery ID) gets its own random stream, so the same place always holds the
## same objects and adding one scenery type does not reshuffle the others.

## Density is objects per this many px².
const DENSITY_AREA: float = 1000000.0


static func chunk_seed(system_seed: int, chunk: Vector2i, scenery_id: String) -> int:
	return hash([system_seed, chunk.x, chunk.y, scenery_id])


static func chunk_of(point: Vector2, chunk_size: float) -> Vector2i:
	return Vector2i(floori(point.x / chunk_size), floori(point.y / chunk_size))


## `elapsed`: game seconds since the system was entered; drifting solid
## scenery is moved on by velocity × elapsed (L4) so it doesn't jump back to
## its start when a chunk reloads. `destroyed` objects are skipped.
static func generate(system_seed: int, chunk: Vector2i, chunk_size: float, entry: LocalSpaceEntry, def: SceneryDef,
		elapsed: float = 0.0, destroyed: DestroyedScenery = null) -> Array[SceneryPlacement]:
	var result: Array[SceneryPlacement] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed(system_seed, chunk, entry.scenery)
	var expected: float = entry.density * chunk_size * chunk_size / DENSITY_AREA
	var count: int = floori(expected)
	if rng.randf() < expected - count:
		count += 1
	var origin := Vector2(chunk) * chunk_size
	for i: int in count:
		# Draw every value even if the point is rejected, so each object's
		# stream position never depends on the region.
		var p := SceneryPlacement.new()
		p.scenery_id = entry.scenery
		p.chunk = chunk
		p.index = i
		p.position = origin + Vector2(rng.randf(), rng.randf()) * chunk_size
		p.size = rng.randf_range(def.size.x, def.size.y)
		p.rotation = rng.randf() * TAU
		p.spin = deg_to_rad(rng.randf_range(def.spin.x, def.spin.y))
		var drift_speed: float = rng.randf_range(def.drift.x, def.drift.y)
		var drift_dir: float = rng.randf() * TAU
		p.velocity = Vector2.from_angle(drift_dir) * drift_speed if def.behaviour == "drift" else Vector2.ZERO
		p.depth = rng.randf_range(def.depth.x, def.depth.y)
		p.look_seed = rng.randi()
		if not entry.contains(p.position):
			continue
		if destroyed != null and destroyed.has(chunk, entry.scenery, i):
			continue
		if def.solid:
			p.position += p.velocity * elapsed
		result.append(p)
	return result
