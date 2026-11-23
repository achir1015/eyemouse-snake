shader_type spatial;
// 火山：深色岩石，山頂有發光的熔岩流
uniform float h = 40.0;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 c = texture(rock, UV * 6.0).rgb * 0.45;
	float y = lp.y / h + 0.5;
	float top = smoothstep(0.86, 0.97, y);
	float streak = smoothstep(0.9, 1.0, sin(atan(lp.z, lp.x) * 9.0 + sin(y * 12.0) * 1.5)) * smoothstep(0.45, 0.95, y);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.35, 0.05) * (top * 3.0 + streak * 1.5);
}
