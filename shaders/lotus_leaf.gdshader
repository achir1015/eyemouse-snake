shader_type spatial;
// 荷葉：從中心放射的葉脈、蠟質（水珠不沾）的霧面
render_mode cull_disabled;
void fragment() {
	vec2 d = UV - 0.5;
	float a = atan(d.y, d.x);
	float r = length(d) * 2.0;
	float vein = 1.0 - smoothstep(0.0, 0.05, abs(sin(a * 11.0)) * r);
	vec3 c = mix(vec3(0.16, 0.36, 0.1), vec3(0.3, 0.5, 0.16), r);
	c = mix(c, vec3(0.5, 0.62, 0.3), vein * 0.5);
	c = mix(c, vec3(0.7, 0.7, 0.35), 1.0 - smoothstep(0.0, 0.08, r));
	ALBEDO = FRONT_FACING ? c : c * 0.7 + vec3(0.05, 0.08, 0.0);
	ROUGHNESS = 0.75;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.2, 0.35, 0.05);
}
