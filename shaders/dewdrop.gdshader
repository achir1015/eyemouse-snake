shader_type spatial;
// 露珠：透明水珠（折射背景＋菲涅耳反光）。
render_mode cull_back;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 off = NORMAL.xy * 0.08 * (1.0 - ndv);
	vec3 refr = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	float fr = pow(1.0 - ndv, 4.0);
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.02;
	SPECULAR = 0.9;
	EMISSION = refr * (0.92 - fr * 0.5) + vec3(0.6, 0.8, 1.0) * fr * 0.15;
}
