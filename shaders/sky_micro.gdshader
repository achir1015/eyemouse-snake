shader_type sky;
// 顯微鏡視野：深色背景、柔和的對稱光暈（暗視野）
render_mode use_quarter_res_pass;
void sky() {
	vec3 d = normalize(EYEDIR);
	float a = abs(d.y);
	vec3 col = mix(vec3(0.01, 0.03, 0.03), vec3(0.02, 0.07, 0.06), pow(1.0 - a, 3.0));
	col += vec3(0.05, 0.12, 0.08) * pow(max(dot(d, vec3(0.0, 1.0, 0.0)), 0.0), 6.0);
	col += vec3(0.08, 0.03, 0.08) * pow(max(dot(d, vec3(0.0, -1.0, 0.0)), 0.0), 6.0);
	COLOR = col;
}
