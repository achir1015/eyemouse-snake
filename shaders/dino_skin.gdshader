shader_type spatial;
// 恐龍皮膚：粗糙皺褶、背深腹淺、斑紋
uniform vec3 back : source_color = vec3(0.32, 0.3, 0.22);
uniform vec3 belly : source_color = vec3(0.6, 0.55, 0.42);
varying vec3 lp;
varying vec3 ln;
void vertex() { lp = VERTEX; ln = NORMAL; }
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void fragment() {
	float up = clamp(ln.y * 0.5 + 0.5, 0.0, 1.0);
	float n = noise(lp * 3.0) * 0.6 + noise(lp * 9.0) * 0.4;
	vec3 c = mix(belly, back, smoothstep(0.35, 0.7, up));
	c *= 0.75 + 0.35 * n;
	c = mix(c, back * 0.6, smoothstep(0.6, 0.75, noise(lp * 1.3)) * up);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	NORMAL_MAP = normalize(vec3(noise(lp * 14.0) - 0.5, noise(lp * 14.0 + 7.0) - 0.5, 1.2)) * 0.5 + 0.5;
}
