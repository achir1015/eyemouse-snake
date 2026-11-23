shader_type spatial;
// 邊界球面：經緯網格，只有蛇頭靠近的地方會亮起來（從球內看，所以畫背面）。
render_mode unshaded, cull_front, blend_add, depth_draw_never;
uniform vec3 head = vec3(0.0);
uniform vec3 tint : source_color = vec3(0.3, 0.9, 1.0);
uniform float base_alpha = 0.03;
uniform float reach = 18.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = UV * vec2(72.0, 36.0);
	vec2 f = abs(fract(g) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.06, min(f.x, f.y));
	float near = 1.0 - smoothstep(0.0, reach, distance(wpos, head));
	ALBEDO = tint * line * (base_alpha + near * 0.9) + tint * near * near * 0.08;
}
