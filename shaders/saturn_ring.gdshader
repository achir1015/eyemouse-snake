shader_type spatial;
// 土星環：平面上依半徑取環的貼圖（Solar System Scope 的環貼圖是一條由內到外的漸層）
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D ring_tex : source_color, filter_linear;
uniform float inner = 0.54;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	if (r < inner || r > 1.0) discard;
	vec4 c = texture(ring_tex, vec2((r - inner) / (1.0 - inner), 0.5));
	if (c.a < 0.05) discard;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.9;
}
