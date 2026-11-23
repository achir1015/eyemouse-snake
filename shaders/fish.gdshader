shader_type spatial;
// 魚：擺尾（越往尾巴擺越大）、銀色魚鱗或錦鯉紅白花紋
uniform float koi = 0.0;
varying vec2 uvv;
varying float seed;
void vertex() {
	seed = INSTANCE_CUSTOM.r;
	float t = clamp(VERTEX.z + 0.5, 0.0, 1.3);
	VERTEX.x += sin(TIME * (5.0 + seed * 3.0) + seed * 20.0 - VERTEX.z * 4.0) * 0.12 * t * t;
	uvv = UV;
}
void fragment() {
	float belly = smoothstep(0.55, 0.8, abs(uvv.y - 0.5) * 2.0);
	vec3 c;
	if (koi > 0.5) {
		float n = sin(uvv.x * 11.0 + seed * 30.0) * sin(uvv.y * 7.0 + seed * 12.0);
		c = mix(vec3(0.97, 0.95, 0.9), vec3(0.95, 0.32, 0.08), step(0.15, n));
		c = mix(c, vec3(0.05), step(0.75, sin(uvv.x * 23.0 + seed * 9.0) * 0.5 + 0.5) * step(0.5, seed) * 0.8);
	} else {
		c = mix(vec3(0.35, 0.45, 0.5), vec3(0.85, 0.88, 0.9), belly);
		c *= 0.85 + 0.15 * sin(uvv.x * 80.0);
	}
	ALBEDO = c;
	METALLIC = koi > 0.5 ? 0.0 : 0.6;
	ROUGHNESS = 0.3;
}
