shader_type spatial;
// 藍金寶石方塊：藍色玻璃核心＋金色發光邊框。
uniform float pulse = 0.0;
void fragment() {
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.06, 0.12, min(e.x, e.y));
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 blue = vec3(0.08, 0.35, 1.0);
	vec3 gold = vec3(1.0, 0.78, 0.22);
	ALBEDO = mix(blue * 0.4, gold, edge);
	METALLIC = edge;
	ROUGHNESS = mix(0.05, 0.25, edge);
	EMISSION = mix(blue * (1.2 + fr * 2.0), gold * 2.4, edge) * (0.8 + 0.4 * pulse);
}
