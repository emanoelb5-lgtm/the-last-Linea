shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.32;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float checker = mod(floor(UV.x / TEXTURE_PIXEL_SIZE.x) + floor(UV.y / TEXTURE_PIXEL_SIZE.y), 2.0);
	vec3 graded = floor(source.rgb * 27.0 + checker * 0.48) / 27.0;
	float vignette = smoothstep(0.85, 0.16, length((UV - 0.5) * vec2(1.18, 1.0)));
	COLOR = vec4(mix(source.rgb, graded, strength) * mix(0.78, 1.0, vignette), 1.0);
}
