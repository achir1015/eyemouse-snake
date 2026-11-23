shader_type sky;
render_mode use_quarter_res_pass;
// 量子領域：六重鏡像對稱的萬花筒星雲（上下也鏡像），洋紅／青藍互補色對稱。
uniform vec3 c1 : source_color = vec3(0.85, 0.18, 0.62);
uniform vec3 c2 : source_color = vec3(0.10, 0.70, 0.95);
uniform vec3 c3 : source_color = vec3(1.00, 0.78, 0.30);
uniform float bright = 1.0;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 6; i++) { s += a * noise(p); p = p * 2.03 + vec3(1.7, 9.2, 3.1); a *= 0.5; } return s; }

void sky() {
	vec3 d = normalize(EYEDIR);
	float az = atan(d.z, d.x);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float sec = TAU / 6.0;
	az = abs(mod(az, sec) - sec * 0.5);
	vec3 p = vec3(cos(az) * cos(el), abs(sin(el)), sin(az) * cos(el)) * 2.6;
	vec3 col;
	if (AT_QUARTER_RES_PASS || AT_CUBEMAP_PASS) {
		// 昂貴的星雲只在 1/4 解析度算一次
		float n = fbm(p);
		float n2 = fbm(p * 2.2 - vec3(n * 1.6));
		float fil = pow(1.0 - abs(n2 - 0.5) * 2.0, 9.0);
		col = mix(c1, c2, smoothstep(0.32, 0.68, n));
		col = col * (0.06 + 0.42 * fil) + c3 * pow(fil, 3.0) * 0.55;
	} else {
		col = QUARTER_RES_COLOR.rgb;
	}
	if (!AT_QUARTER_RES_PASS) {
		vec3 q = p * 40.0;
		float st = pow(hash(floor(q)), 40.0) * 2.0;
		col += vec3(st) * (0.6 + 0.4 * c2);
		col += mix(c2, c3, 0.5) * pow(abs(d.y), 14.0) * 0.6;
	}
	COLOR = col * bright;
}
