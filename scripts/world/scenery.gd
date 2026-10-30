class_name Scenery
extends Node2D
## One generic local-space object (L1, L3, L4), configured entirely from its
## SceneryDef and a SceneryPlacement. Solid scenery gets a hitbox and Health;
## cosmetic scenery (dust) gets neither and may sit at a parallax depth.

signal scenery_destroyed(scenery: Scenery)

const SPRITE_DIR: String = "res://assets/sprites"

var def: SceneryDef
var placement: SceneryPlacement
## Hit circle radius; 0 when not solid.
var hit_radius: float = 0.0
var health: Health = null

@onready var visual: Node2D = $Visual


func setup(p_def: SceneryDef, p_placement: SceneryPlacement) -> void:
	def = p_def
	placement = p_placement
	position = placement.position
	rotation = placement.rotation
	visual.add_child(build_visual(def, placement.size, placement.look_seed))
	if def.solid:
		hit_radius = placement.size / 2.0
		add_to_group(&"solid_scenery")
		var area := Area2D.new()
		area.name = "Hitbox"
		area.monitoring = false
		area.collision_layer = 2
		area.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = hit_radius
		shape.shape = circle
		area.add_child(shape)
		add_child(area)
		health = Health.new()
		health.name = "Health"
		health.setup(0.0, def.armor)
		add_child(health)
		health.destroyed.connect(func() -> void: scenery_destroyed.emit(self))
	set_physics_process(placement.velocity != Vector2.ZERO or placement.spin != 0.0)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	position += placement.velocity * delta
	rotation += placement.spin * delta


## Shifts the drawing for parallax depth: depth < 1 lags the camera, so the
## object seems further away. Called by LocalSpace each physics frame.
func apply_depth(camera_centre: Vector2) -> void:
	var offset: Vector2 = (global_position - camera_centre) * (placement.depth - 1.0)
	visual.position = offset.rotated(-rotation)


## The object's look: a sprite picked from the definition, or a rough
## placeholder polygon. Also used for fragments.
static func build_visual(p_def: SceneryDef, size: float, look_seed: int) -> Node2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	if not p_def.sprites.is_empty():
		var path: String = SPRITE_DIR.path_join(p_def.sprites[rng.randi() % p_def.sprites.size()])
		if ResourceLoader.exists(path):
			var sprite: Sprite2D = LitSprite.build(path)  # V9: lit when the art has maps
			var tex_size: float = maxf(sprite.texture.get_width(), sprite.texture.get_height())
			sprite.scale = Vector2.ONE * (size / tex_size)
			return sprite
	var points := PackedVector2Array()
	var radius: float = size / 2.0
	for i: int in p_def.sides:
		var angle: float = TAU * (i + rng.randf_range(-0.3, 0.3) * p_def.roughness) / p_def.sides
		var r: float = radius * (1.0 - rng.randf() * p_def.roughness)
		points.append(Vector2(cos(angle) * r * p_def.aspect, sin(angle) * r) / sqrt(p_def.aspect))
	var polygon := Polygon2D.new()
	polygon.polygon = points
	var shade: float = rng.randf_range(0.85, 1.1)
	polygon.color = Color(p_def.colour.r * shade, p_def.colour.g * shade, p_def.colour.b * shade, p_def.colour.a)
	polygon.material = LitSprite.unshaded_material()
	return polygon
