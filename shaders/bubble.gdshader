shader_type spatial;
// 量子泡泡：薄膜干涉的彩虹邊緣，中間透明。
render_mode blend_add, depth_draw_never, unshaded, cull_back;
uniform float strength = 0.7;
void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = pow(1.0 - ndv, 3.0);
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + ndv * 2.2 + TIME * 0.05));
	ALBEDO = film * fr * strength;
}
