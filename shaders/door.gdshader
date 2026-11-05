shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.30,0.54,0.49);
void fragment() {
	float grain = fract(sin(dot(floor(UV * vec2(32.0,64.0)),vec2(12.98,78.23))) * 43758.54);
	float wave = 0.5 + 0.5 * sin(UV.y * 35.0 - TIME * 0.8 + sin(UV.x * 20.0));
	ALBEDO = tint * (0.3 + grain * 0.25 + wave * 0.4);
	EMISSION = tint * wave * 0.24;
	ALPHA = 0.72;
}
