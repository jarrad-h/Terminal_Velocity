class_name BackdropDef
extends Resource
## B2: a system's distant backdrop of noise nebula and stars. Part of SystemDef.

var parallax: float
var base_colour: Color
var star_density: float
var star_brightness: float
var star_size: float
var star_spacing: float
var nebula_coverage: float
var nebula_intensity: float
var nebula_softness: float
var gradient: Array[Color] = []
var noise_seed: int
var noise_frequency: float
var noise_octaves: int
var noise_texture_size: int
var noise_scale: float


static func parse(r: DefReader) -> BackdropDef:
	var d := BackdropDef.new()
	d.parallax = r.number("parallax", 0.02, false, 0.0)
	d.base_colour = r.colour("base_colour", Color("#05060c"))
	var stars: DefReader = r.object("stars")
	d.star_density = stars.number("density", 0.05, false, 0.0)
	d.star_brightness = stars.number("brightness", 0.8, false, 0.0)
	d.star_size = stars.number("size", 1.2, false, 0.1)
	d.star_spacing = stars.number("spacing", 16.0, false, 2.0)
	var nebula: DefReader = r.object("nebula")
	d.nebula_coverage = nebula.number("coverage", 0.4, false, 0.0)
	d.nebula_intensity = nebula.number("intensity", 0.6, false, 0.0)
	d.nebula_softness = nebula.number("softness", 0.3, false, 0.01)
	var hexes: Array[String] = nebula.string_array("gradient")
	for i: int in hexes.size():
		if Color.html_is_valid(hexes[i]):
			d.gradient.append(Color.html(hexes[i]))
		else:
			nebula.error("gradient[%d]" % i, "expected a colour like \"#88ccff\"")
	if d.gradient.size() < 2:
		d.gradient = [Color("#10142a"), Color("#3a2a6a"), Color("#a05a8a")]
	var noise: DefReader = r.object("noise")
	d.noise_seed = noise.integer("seed", 0)
	d.noise_frequency = noise.number("frequency", 0.006, false, 0.0)
	d.noise_octaves = noise.integer("octaves", 5, false, 1)
	d.noise_texture_size = noise.integer("texture_size", 1024, false, 64)
	d.noise_scale = noise.number("scale", 2.0, false, 0.1)
	return d
