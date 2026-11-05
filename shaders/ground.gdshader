shader_type spatial;
render_mode diffuse_burley;
uniform vec3 dark_color : source_color = vec3(0.15, 0.19, 0.17);
uniform vec3 light_color : source_color = vec3(0.25, 0.28, 0.23);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 cell = floor(world_pos.xz * 5.0);
	float grain = hash(cell);
	float patch = hash(floor(world_pos.xz * 0.45));
	float clearing = 1.0 - smoothstep(3.0, 7.0, length(world_pos.xz));
	ALBEDO = mix(dark_color, light_color, grain * 0.5 + patch * 0.3);
	ALBEDO = mix(ALBEDO, vec3(0.25,0.22,0.18) * (0.8 + grain * 0.25), clearing);
	ROUGHNESS = 1.0;
}
