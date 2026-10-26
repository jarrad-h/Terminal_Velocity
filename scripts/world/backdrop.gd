class_name Backdrop
extends CanvasLayer
## B1–B2: noise nebula and stars drawn behind everything on a screen-space
## layer that moves at the system's parallax factor (default 0.02).

const SHADER: Shader = preload("res://assets/shaders/backdrop.gdshader")

var def: BackdropDef = null
var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = -100
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	add_child(_rect)


func configure(p_def: BackdropDef) -> void:
	def = p_def
	RenderingServer.set_default_clear_color(def.base_colour)

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = def.noise_seed
	noise.frequency = def.noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = def.noise_octaves
	var noise_texture := NoiseTexture2D.new()
	noise_texture.width = def.noise_texture_size
	noise_texture.height = def.noise_texture_size
	noise_texture.seamless = true
	noise_texture.noise = noise

	var gradient := Gradient.new()
	var colours := PackedColorArray(def.gradient)
	var offsets := PackedFloat32Array()
	for i: int in colours.size():
		offsets.append(float(i) / (colours.size() - 1))
	gradient.colors = colours
	gradient.offsets = offsets
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient

	_material.set_shader_parameter("nebula_noise", noise_texture)
	_material.set_shader_parameter("nebula_gradient", gradient_texture)
	_material.set_shader_parameter("base_colour", def.base_colour)
	_material.set_shader_parameter("noise_texture_size", float(def.noise_texture_size))
	_material.set_shader_parameter("noise_scale", def.noise_scale)
	_material.set_shader_parameter("nebula_coverage", def.nebula_coverage)
	_material.set_shader_parameter("nebula_intensity", def.nebula_intensity)
	_material.set_shader_parameter("nebula_softness", def.nebula_softness)
	_material.set_shader_parameter("star_spacing", def.star_spacing)
	_material.set_shader_parameter("star_density", def.star_density)
	_material.set_shader_parameter("star_brightness", def.star_brightness)
	_material.set_shader_parameter("star_size", def.star_size)


func _process(_delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if def == null or camera == null:
		return
	var size: Vector2 = _rect.size
	_material.set_shader_parameter("rect_size", size)
	_material.set_shader_parameter("offset", camera.get_screen_center_position() * def.parallax - size / 2.0)
