shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.44, 0.56, 0.55, 0.12);
void vertex() { VERTEX.x += sin(TIME * 0.14 + MODEL_MATRIX[3].z) * 2.0; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = max(0.0, 1.0 - dot(p,p));
	float cloud = 0.7 + 0.3 * sin(UV.x * 17.0 + TIME * 0.13) * sin(UV.y * 9.0 + TIME * 0.2);
	ALBEDO = tint.rgb;
	ALPHA = edge * edge * cloud * tint.a;
}
