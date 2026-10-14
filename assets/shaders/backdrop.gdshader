// B1–B2: distant backdrop. Nebula from a FastNoiseLite texture coloured by a
// gradient, plus hashed point stars. Every uniform is set from the system's
// backdrop definition by scripts/world/backdrop.gd.
shader_type canvas_item;

uniform sampler2D nebula_noise : repeat_enable, filter_linear;
uniform sampler2D nebula_gradient : repeat_disable, filter_linear;
uniform vec2 rect_size = vec2(1600.0, 900.0);
// Backdrop-space position of the screen's top-left corner (camera × parallax).
uniform vec2 offset = vec2(0.0);
uniform vec4 base_colour : source_color = vec4(0.02, 0.024, 0.047, 1.0);
uniform float noise_texture_size = 1024.0;
uniform float noise_scale = 2.0;
uniform float nebula_coverage = 0.4;
uniform float nebula_intensity = 0.6;
uniform float nebula_softness = 0.3;
uniform float star_spacing = 16.0;
uniform float star_density = 0.05;
uniform float star_brightness = 0.8;
uniform float star_size = 1.2;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 p = UV * rect_size + offset;

	float n = texture(nebula_noise, p / (noise_texture_size * noise_scale)).r;
	float edge = 1.0 - nebula_coverage;
	float amount = smoothstep(edge, edge + nebula_softness, n) * nebula_intensity;
	vec3 nebula = texture(nebula_gradient, vec2(clamp((n - edge) / max(1.0 - edge, 0.001), 0.0, 1.0), 0.5)).rgb;
	vec3 colour = mix(base_colour.rgb, nebula, clamp(amount, 0.0, 1.0));

	vec2 cell = floor(p / star_spacing);
	if (hash(cell) < star_density) {
		vec2 star = (cell + vec2(hash(cell + 17.0), hash(cell + 31.0))) * star_spacing;
		float glow = 1.0 - smoothstep(0.0, star_size, length(p - star));
		colour += vec3(glow * star_brightness * (0.35 + 0.65 * hash(cell + 47.0)));
	}
	COLOR = vec4(colour, 1.0);
}
