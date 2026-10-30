shader_type canvas_item;
render_mode blend_add, unshaded;
// V9: a planet's city lights, shown only on the side away from the star.
// light_to_star: unit vector from the planet towards the light, in the
// sprite's image space (+x right, +y down), and the light's height (0–1).

uniform sampler2D normal_map : hint_normal;
uniform vec2 light_to_star = vec2(1.0, 0.0);
uniform float light_height = 0.3;
uniform float softness = 0.25;

void fragment() {
	vec4 glow = texture(TEXTURE, UV);
	vec3 n = texture(normal_map, UV).rgb * 2.0 - 1.0;  // +y up the image
	vec3 to_light = normalize(vec3(light_to_star.x, -light_to_star.y, light_height));
	float day = dot(normalize(n), to_light);
	COLOR = glow * COLOR.a * (1.0 - smoothstep(-softness, softness, day));
}
