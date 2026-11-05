shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.65,0.79,0.65,0.8);
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a*(0.68+0.22*sin(TIME*3.2));
}
