shader_type spatial;
// 海帶／水草：越高擺動越大，半透明葉肉
render_mode cull_disabled;
uniform vec3 col : source_color = vec3(0.25, 0.42, 0.12);
uniform float height = 20.0;
uniform float phase = 0.0;
void vertex() {
	float k = VERTEX.y / max(height, 0.01);
	VERTEX.x += sin(TIME * 0.8 + phase + VERTEX.y * 0.15) * k * k * 2.2;
	VERTEX.z += cos(TIME * 0.6 + phase * 1.3 + VERTEX.y * 0.12) * k * k * 1.4;
}
void fragment() {
	float vein = 1.0 - smoothstep(0.0, 0.06, abs(UV.x - 0.5));
	vec3 c = col * (0.75 + 0.35 * UV.y) + vec3(0.08, 0.1, 0.0) * vein;
	ALBEDO = c;
	ROUGHNESS = 0.55;
	BACKLIGHT = col * 0.8;
}
