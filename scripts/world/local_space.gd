class_name LocalSpace
extends Node2D
## L1–L2: streams scenery in fixed-size chunks around the camera. Chunks are
## generated from the system seed so the same place always holds the same
## objects; chunks more than one chunk outside the view are unloaded.

const SCENERY_SCENE: PackedScene = preload("res://scenes/scenery.tscn")

var system: SystemDef = null
var chunk_size: float = 1024.0
## Vector2i -> Node2D holding that chunk's scenery.
var _chunks: Dictionary = {}
## Vector2i -> Array[Scenery] with depth != 1, moved for parallax each frame.
var _depth_objects: Dictionary = {}


func _ready() -> void:
	# After the ship and camera have moved this frame.
	process_physics_priority = 20


func configure(p_system: SystemDef, p_chunk_size: float) -> void:
	system = p_system
	chunk_size = p_chunk_size
	clear()


func clear() -> void:
	for node: Node2D in _chunks.values():
		node.queue_free()
	_chunks.clear()
	_depth_objects.clear()


func loaded_chunks() -> Array:
	return _chunks.keys()


func object_count() -> int:
	var total: int = 0
	for node: Node2D in _chunks.values():
		total += node.get_child_count()
	return total


func _physics_process(_delta: float) -> void:
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
			_chunks[chunk].queue_free()
			_chunks.erase(chunk)
			_depth_objects.erase(chunk)
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
		for placement: SceneryPlacement in SceneryGen.generate(system.system_seed, chunk, chunk_size, entry, def):
			var scenery: Scenery = SCENERY_SCENE.instantiate()
			holder.add_child(scenery)
			scenery.setup(def, placement)
			if placement.depth != 1.0:
				depth_list.append(scenery)
	if not depth_list.is_empty():
		_depth_objects[chunk] = depth_list
