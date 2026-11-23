shader_type spatial;
// 顯微鏡下的細胞／細菌：半透明膜、邊緣螢光（暗視野螢光顯微鏡的感覺）
render_mode blend_add, depth_draw_never, cull_back;
uniform vec3 tint : source_color = vec3(0.4, 1.0, 0.6);
uniform float glow = 1.0;
void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = pow(1.0 - ndv, 2.5);
	float grain = 0.85 + 0.15 * sin(UV.x * 120.0) * sin(UV.y * 90.0);
	ALBEDO = vec3(0.0);
	EMISSION = tint * (0.05 + fr * 1.2) * glow * grain;
}
