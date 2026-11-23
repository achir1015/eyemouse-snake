shader_type sky;
render_mode use_quarter_res_pass;
// 星雲宇宙：深藍紫色星雲、密集星點、一顆明亮的藍白恆星與星芒。
uniform vec3 neb_a : source_color = vec3(0.06, 0.12, 0.42);
uniform vec3 neb_b : source_color = vec3(0.35, 0.18, 0.55);
uniform vec3 star_col : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 star_dir = vec3(0.0, 0.25, -1.0);

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 6; i++) { s += a * noise(p); p = p * 2.07 + vec3(3.3, 1.1, 7.7); a *= 0.5; } return s; }

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col;
	if (AT_QUARTER_RES_PASS || AT_CUBEMAP_PASS) {
		float n = fbm(d * 2.2);
		float n2 = fbm(d * 4.5 + vec3(n * 2.0));
		col = mix(neb_a, neb_b, smoothstep(0.35, 0.75, n2)) * (0.25 + 1.1 * pow(n, 2.5));
		col += vec3(0.05, 0.08, 0.2) * smoothstep(0.55, 0.9, n2);
	} else {
		col = QUARTER_RES_COLOR.rgb;
	}
	if (!AT_QUARTER_RES_PASS) {
		float stars = 0.0;
		for (int k = 0; k < 2; k++) {
			vec3 q = d * (180.0 + float(k) * 210.0);
			vec3 c = floor(q);
			float h = hash(c + float(k) * 13.0);
			float m = step(0.985, h) * (1.0 - smoothstep(0.0, 0.45, length(fract(q) - 0.5)));
			stars += m * (0.6 + 0.8 * hash(c * 1.7));
		}
		col += vec3(stars) * vec3(0.85, 0.92, 1.0);
		vec3 sd = normalize(star_dir);
		float a = max(dot(d, sd), 0.0);
		col += star_col * (pow(a, 900.0) * 30.0 + pow(a, 60.0) * 1.2 + pow(a, 8.0) * 0.25);
		vec3 r = normalize(cross(sd, vec3(0.0, 1.0, 0.0)));
		vec3 u = cross(r, sd);
		vec2 pp = vec2(dot(d, r), dot(d, u));
		col += star_col * pow(a, 20.0) * (exp(-abs(pp.x) * 300.0) + exp(-abs(pp.y) * 300.0)) * 2.0;
	}
	COLOR = col;
}
