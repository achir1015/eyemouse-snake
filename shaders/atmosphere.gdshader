shader_type spatial;
// 地球大氣層：邊緣藍色光暈
render_mode unshaded, blend_add, cull_back, depth_draw_never;
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = vec3(0.3, 0.6, 1.0) * fr * 1.4;
}
