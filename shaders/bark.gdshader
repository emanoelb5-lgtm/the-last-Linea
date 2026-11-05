shader_type spatial;
uniform vec3 bark_color : source_color = vec3(0.22,0.24,0.22);
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float n = fract(sin(dot(floor(local_pos.xz * 15.0) + floor(local_pos.y * 5.0), vec2(12.98,78.23))) * 43758.54);
	ALBEDO = bark_color * (0.65 + floor(n * 4.0) * 0.17);
	ROUGHNESS = 1.0;
}
