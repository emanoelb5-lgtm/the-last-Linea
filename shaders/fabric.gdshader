shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.23,0.3,0.31,1.0);
void fragment() {
	vec2 cell = floor(UV*vec2(64.0,36.0));
	float grain = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
	ALBEDO = base_color.rgb*(0.9+floor(grain*3.0)*0.075);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
