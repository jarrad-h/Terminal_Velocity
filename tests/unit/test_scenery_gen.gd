extends TestCase
## L2/L3: deterministic chunk generation, density and regions.

const CHUNK: float = 1000.0


func _def(behaviour: String = "static", solid: bool = false) -> SceneryDef:
	var d := SceneryDef.new()
	d.solid = solid
	d.id = "rock"
	d.size = Vector2(10.0, 20.0)
	d.spin = Vector2(-10.0, 10.0)
	d.drift = Vector2(5.0, 5.0)
	d.depth = Vector2.ONE
	d.behaviour = behaviour
	return d


func _gen(chunk: Vector2i, entry: LocalSpaceEntry, def: SceneryDef = _def(), seed_value: int = 42) -> Array[SceneryPlacement]:
	return SceneryGen.generate(seed_value, chunk, CHUNK, entry, def)


func _positions(list: Array[SceneryPlacement]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: SceneryPlacement in list:
		out.append(p.position)
	return out


func test_same_chunk_same_objects() -> void:
	var entry := LocalSpaceEntry.create("rock", 20.0)
	var a: Array[SceneryPlacement] = _gen(Vector2i(3, -2), entry)
	var b: Array[SceneryPlacement] = _gen(Vector2i(3, -2), entry)
	assert_true(a.size() > 0, "something generated")
	assert_true(_positions(a) == _positions(b), "revisiting a chunk gives the same objects")
	assert_near(a[0].size, b[0].size, "same size")
	assert_true(a[0].look_seed == b[0].look_seed, "same look")


func test_different_chunk_or_seed_differs() -> void:
	var entry := LocalSpaceEntry.create("rock", 20.0)
	var a: Array[Vector2] = _positions(_gen(Vector2i(0, 0), entry))
	assert_true(a != _positions(_gen(Vector2i(1, 0), entry)), "neighbour chunk differs")
	assert_true(a != _positions(_gen(Vector2i(0, 0), entry, _def(), 43)), "other system seed differs")


func test_scenery_id_has_its_own_stream() -> void:
	var rock: Array[Vector2] = _positions(_gen(Vector2i.ZERO, LocalSpaceEntry.create("rock", 20.0)))
	var dust: Array[Vector2] = _positions(_gen(Vector2i.ZERO, LocalSpaceEntry.create("dust", 20.0)))
	assert_true(rock != dust, "different scenery IDs are placed independently")


func test_objects_stay_inside_their_chunk() -> void:
	var list: Array[SceneryPlacement] = _gen(Vector2i(-1, 2), LocalSpaceEntry.create("rock", 50.0))
	var rect := Rect2(Vector2(-1.0, 2.0) * CHUNK, Vector2(CHUNK, CHUNK))
	for p: SceneryPlacement in list:
		assert_true(rect.has_point(p.position), "%s inside chunk" % p.position)


func test_density_is_per_million_px2() -> void:
	var entry := LocalSpaceEntry.create("rock", 5.0)
	var total: int = 0
	for x: int in 20:
		for y: int in 20:
			total += _gen(Vector2i(x, y), entry).size()
	# 400 chunks of 1 Mpx² at density 5 -> about 2000.
	assert_true(total > 1800 and total < 2200, "about 2000 objects, got %d" % total)


func test_values_within_definition_ranges() -> void:
	for p: SceneryPlacement in _gen(Vector2i.ZERO, LocalSpaceEntry.create("rock", 50.0)):
		assert_true(p.size >= 10.0 and p.size <= 20.0, "size in range")
		assert_true(absf(p.spin) <= deg_to_rad(10.0) + 0.0001, "spin in range")
		assert_true(p.velocity == Vector2.ZERO, "static scenery does not drift")


func test_drift_behaviour_moves() -> void:
	for p: SceneryPlacement in _gen(Vector2i.ZERO, LocalSpaceEntry.create("rock", 20.0), _def("drift")):
		assert_near(p.velocity.length(), 5.0, "drift speed from range")


func test_circle_region() -> void:
	var entry := LocalSpaceEntry.create("rock", 50.0, "circle", Vector2(500.0, 500.0), 300.0)
	var list: Array[SceneryPlacement] = _gen(Vector2i.ZERO, entry)
	assert_true(list.size() > 0, "some objects inside the circle")
	for p: SceneryPlacement in list:
		assert_true(p.position.distance_to(Vector2(500.0, 500.0)) <= 300.0, "inside circle")
	assert_true(_gen(Vector2i(5, 5), entry).is_empty(), "nothing in a far chunk")


func test_ring_region() -> void:
	var entry := LocalSpaceEntry.create("rock", 50.0, "ring", Vector2.ZERO, 1500.0, 1000.0)
	var count: int = 0
	for x: int in range(-2, 2):
		for y: int in range(-2, 2):
			for p: SceneryPlacement in _gen(Vector2i(x, y), entry):
				var d: float = p.position.length()
				assert_true(d >= 1000.0 and d <= 1500.0, "inside ring, got distance %f" % d)
				count += 1
	assert_true(count > 0, "ring has objects")


func test_region_does_not_shift_objects() -> void:
	# The same object is at the same place whether or not a region filters others.
	var whole: Array[Vector2] = _positions(_gen(Vector2i.ZERO, LocalSpaceEntry.create("rock", 50.0)))
	var circle: Array[Vector2] = _positions(_gen(Vector2i.ZERO, LocalSpaceEntry.create("rock", 50.0, "circle", Vector2(500.0, 500.0), 300.0)))
	for p: Vector2 in circle:
		assert_true(p in whole, "filtered object keeps its place")


func test_destroyed_objects_are_skipped_and_others_unchanged() -> void:
	var entry := LocalSpaceEntry.create("rock", 20.0)
	var all: Array[SceneryPlacement] = _gen(Vector2i(2, 2), entry)
	var gone: SceneryPlacement = all[1]
	var destroyed := DestroyedScenery.new()
	destroyed.add(Vector2i(2, 2), "rock", gone.index)
	var after: Array[SceneryPlacement] = SceneryGen.generate(42, Vector2i(2, 2), CHUNK, entry, _def(), 0.0, destroyed)
	assert_true(after.size() == all.size() - 1, "one fewer object")
	assert_true(not _positions(after).has(gone.position), "destroyed object not regenerated")
	var others: Array[Vector2] = _positions(all)
	others.erase(gone.position)
	assert_true(_positions(after) == others, "the rest are unchanged")


func test_destroyed_key_is_per_chunk_and_type() -> void:
	var destroyed := DestroyedScenery.new()
	destroyed.add(Vector2i(0, 0), "rock", 3)
	assert_true(destroyed.has(Vector2i(0, 0), "rock", 3), "same key")
	assert_true(not destroyed.has(Vector2i(1, 0), "rock", 3), "other chunk")
	assert_true(not destroyed.has(Vector2i(0, 0), "dust", 3), "other type")
	destroyed.clear()
	assert_true(destroyed.size() == 0, "cleared")


func test_drifting_solid_scenery_moves_with_elapsed_time() -> void:
	var entry := LocalSpaceEntry.create("rock", 20.0)
	var start: Array[SceneryPlacement] = SceneryGen.generate(42, Vector2i.ZERO, CHUNK, entry, _def("drift", true), 0.0)
	var later: Array[SceneryPlacement] = SceneryGen.generate(42, Vector2i.ZERO, CHUNK, entry, _def("drift", true), 10.0)
	assert_true(start.size() == later.size(), "same objects")
	for i: int in start.size():
		assert_vec_near(later[i].position, start[i].position + start[i].velocity * 10.0, "offset by velocity × elapsed")


func test_non_solid_scenery_skips_drift_offset() -> void:
	var entry := LocalSpaceEntry.create("dust", 20.0)
	var start: Array[Vector2] = _positions(SceneryGen.generate(42, Vector2i.ZERO, CHUNK, entry, _def("drift", false), 0.0))
	var later: Array[Vector2] = _positions(SceneryGen.generate(42, Vector2i.ZERO, CHUNK, entry, _def("drift", false), 10.0))
	assert_true(start == later, "dust stays at its generated place")
