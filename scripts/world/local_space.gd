class_name LocalSpace
extends Node2D
## L1–L2: streams scenery in fixed-size chunks around the camera. Chunks are
## generated from the system seed so the same place always holds the same
## objects; chunks more than one chunk outside the view are unloaded.
## L4: destroyed scenery is remembered until the system changes, and drifting
## solid scenery is generated where its drift has taken it by now.

const SCENERY_SCENE: PackedScene = preload("res://scenes/scenery.tscn")

var system: SystemDef = null
var chunk_size: float = 1024.0
## Vector2i -> Node2D holding that chunk's scenery.
var _chunks: Dictionary = {}
## Vector2i -> Array[Scenery] with depth != 1, moved for parallax each frame.
var _depth_objects: Dictionary = {}
## H2: loaded scenery whose definition sets radar: true.
var _radar_objects: Array[Scenery] = []
## H2: chunk -> radar-visible placements (start positions) for chunks that
## aren't loaded, so the radar sees its full range without building nodes.
var _radar_cache: Dictionary = {}
var destroyed: DestroyedScenery = DestroyedScenery.new()
## Game seconds since this system was entered (scaled time, stops when paused).
var elapsed: float = 0.0


func _ready() -> void:
	# After the ship and camera have moved this frame.
	process_physics_priority = 20


## A different system starts fresh; the same one (hot reload) keeps its
## destroyed set and clock.
func configure(p_system: SystemDef, p_chunk_size: float) -> void:
	if system == null or p_system.id != system.id:
		destroyed.clear()
		elapsed = 0.0
	system = p_system
	chunk_size = p_chunk_size
	clear()


## C10: rescue counts as leaving and returning — forget destroyed scenery
## and the drift clock, then regenerate.
func reset_visit() -> void:
	destroyed.clear()
	elapsed = 0.0
	clear()
	for node: Node in get_children():
		if node is Fragment or node is Flash:
			node.queue_free()


func clear() -> void:
	_radar_cache.clear()
	for node: Node2D in _chunks.values():
		node.queue_free()
	_chunks.clear()
	_depth_objects.clear()
	_radar_objects.clear()


## H2: scenery to draw on the radar (only types with radar: true).
func radar_objects() -> Array[Scenery]:
	return _radar_objects


func loaded_chunks() -> Array:
	return _chunks.keys()


## The node holding a loaded chunk's scenery, or null.
func chunk_node(chunk: Vector2i) -> Node2D:
	return _chunks.get(chunk)


## H2: where radar-visible scenery in unloaded chunks is now, within `radius`
## of `centre`. Generated from the seed like the chunks themselves (L2), so
## each object appears on the radar where it will be when its chunk loads.
func distant_radar_points(centre: Vector2, radius: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if system == null:
		return result
	if _radar_cache.size() > 1024:
		_radar_cache.clear()
	var lo: Vector2i = SceneryGen.chunk_of(centre - Vector2(radius, radius), chunk_size)
	var hi: Vector2i = SceneryGen.chunk_of(centre + Vector2(radius, radius), chunk_size)
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			var chunk := Vector2i(x, y)
			if _chunks.has(chunk):
				continue
			if not _radar_cache.has(chunk):
				_radar_cache[chunk] = _radar_placements(chunk)
			for p: SceneryPlacement in _radar_cache[chunk]:
				if destroyed.has(p.chunk, p.scenery_id, p.index):
					continue
				var at: Vector2 = p.position + p.velocity * elapsed
				if at.distance_squared_to(centre) <= radius * radius:
					result.append(at)
	return result


## Radar-visible placements of one chunk at their start positions; velocity
## kept only for solid scenery, which is the only kind that drifts on (L4).
func _radar_placements(chunk: Vector2i) -> Array[SceneryPlacement]:
	var result: Array[SceneryPlacement] = []
	for entry: LocalSpaceEntry in system.local_space:
		var def: SceneryDef = DataRegistry.get_scenery(entry.scenery)
		if not def.radar:
			continue
		for p: SceneryPlacement in SceneryGen.generate(system.system_seed, chunk, chunk_size, entry, def):
			if not def.solid:
				p.velocity = Vector2.ZERO
			result.append(p)
	return result


func object_count() -> int:
	var total: int = 0
	for node: Node2D in _chunks.values():
		total += node.get_child_count()
	return total


func _physics_process(delta: float) -> void:
	elapsed += delta
	var camera: Camera2D = get_viewport().get_camera_2d()
	if system == null or camera == null:
		return
	var centre: Vector2 = camera.get_screen_center_position()
	var half_view: Vector2 = get_viewport().get_visible_rect().size / camera.zoom / 2.0
	var lo: Vector2i = SceneryGen.chunk_of(centre - half_view, chunk_size) - Vector2i.ONE
	var hi: Vector2i = SceneryGen.chunk_of(centre + half_view, chunk_size) + Vector2i.ONE
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			var chunk := Vector2i(x, y)
			if not _chunks.has(chunk):
				_load_chunk(chunk)
	# Unload with one extra chunk of slack so flying along a border doesn't thrash.
	for chunk: Vector2i in _chunks.keys():
		if chunk.x < lo.x - 1 or chunk.x > hi.x + 1 or chunk.y < lo.y - 1 or chunk.y > hi.y + 1:
			_unload_chunk(chunk)
	for list: Array in _depth_objects.values():
		for scenery: Scenery in list:
			scenery.apply_depth(centre)


func _load_chunk(chunk: Vector2i) -> void:
	var holder := Node2D.new()
	holder.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	add_child(holder)
	_chunks[chunk] = holder
	var depth_list: Array[Scenery] = []
	for entry: LocalSpaceEntry in system.local_space:
		var def: SceneryDef = DataRegistry.get_scenery(entry.scenery)
		for placement: SceneryPlacement in SceneryGen.generate(system.system_seed, chunk, chunk_size, entry, def, elapsed, destroyed):
			var scenery: Scenery = SCENERY_SCENE.instantiate()
			holder.add_child(scenery)
			scenery.setup(def, placement)
			if placement.depth != 1.0:
				depth_list.append(scenery)
			if def.radar:
				_radar_objects.append(scenery)
			if def.solid:
				scenery.scenery_destroyed.connect(_on_scenery_destroyed)
	if not depth_list.is_empty():
		_depth_objects[chunk] = depth_list


func _unload_chunk(chunk: Vector2i) -> void:
	var holder: Node2D = _chunks[chunk]
	for child: Node in holder.get_children():
		_radar_objects.erase(child)
	holder.queue_free()
	_chunks.erase(chunk)
	_depth_objects.erase(chunk)


## L4: remember it, throw off fragments, remove it.
func _on_scenery_destroyed(scenery: Scenery) -> void:
	var placement: SceneryPlacement = scenery.placement
	destroyed.add(placement.chunk, placement.scenery_id, placement.index)
	_radar_objects.erase(scenery)
	var def: SceneryDef = scenery.def
	Flash.spawn(self, scenery.global_position, placement.size, def.colour.lightened(0.5), 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = placement.look_seed
	for fragment: Dictionary in def.fragments:
		var piece_def: SceneryDef = DataRegistry.get_scenery(fragment["scenery"])
		for i: int in fragment["count"]:
			Fragment.spawn(self, piece_def, scenery.global_position, placement.velocity,
				rng.randf_range(def.fragment_speed.x, def.fragment_speed.y), def.fragment_lifetime, rng.randi())
	scenery.queue_free()
