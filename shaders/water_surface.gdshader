shader_type spatial;
// 水面：從水下看會有波動的亮面（全反射的藍綠色）＋從水上看是半透明的水
render_mode cull_disabled, depth_draw_never;
uniform float murky = 0.0;
float h(vec2 p) {
	return sin(p.x * 0.35 + TIME * 0.9) * 0.5 + sin(p.y * 0.27 - TIME * 0.7) * 0.5 + sin((p.x + p.y) * 0.6 + TIME * 1.4) * 0.25;
}
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += h(wp.xz) * 0.15;
}
void fragment() {
	vec2 e = vec2(0.5, 0.0);
	vec3 n = normalize(vec3(h(wp.xz - e.xy) - h(wp.xz + e.xy), 2.0, h(wp.xz - e.yx) - h(wp.xz + e.yx)));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 deep = mix(vec3(0.05, 0.35, 0.45), vec3(0.2, 0.28, 0.12), murky);
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = deep;
	ROUGHNESS = 0.05;
	METALLIC = 0.2;
	ALPHA = mix(0.55, 0.9, fr);
	EMISSION = deep * 0.4 + vec3(0.6, 0.8, 0.8) * pow(max(n.x * 0.7 + 0.3, 0.0), 8.0) * 0.4;
}
