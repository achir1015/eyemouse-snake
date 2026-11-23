shader_type spatial;
// 光環：沿著圓環流動的對稱漸層光（青 ↔ 金）。
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 a : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 b : source_color = vec3(1.0, 0.75, 0.25);
uniform float power = 1.0;
void fragment() {
	float t = abs(sin((UV.x * 2.0 + TIME * 0.25) * PI * 2.0));
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = mix(a, b, t) * (0.35 + 1.4 * rim) * power;
}
