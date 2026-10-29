// H3: draws a texture as a flat silhouette in the draw call's colour
// (keeps only the texture's alpha). Used by the target panel schematic.
shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = vec4(tint.rgb, tint.a * texture(TEXTURE, UV).a);
}
