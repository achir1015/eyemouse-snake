shader_type spatial;
// 蛇皮：UV.x 繞身體一圈（0＝背脊、0.5＝腹部），UV.y＝離蛇頭的距離（公尺）。
// 背上左右對稱的菱形花紋、立體鱗片（法線）、腹部淡色、清漆光澤。
uniform vec3 col_back : source_color = vec3(0.05, 0.22, 0.09);
uniform vec3 col_pat : source_color = vec3(0.55, 0.45, 0.12);
uniform vec3 col_belly : source_color = vec3(0.72, 0.68, 0.48);
uniform float scale_u = 26.0;
uniform float scale_v = 3.4;
uniform float hurt = 0.0;
uniform float glow = 0.0;
uniform float shimmer = 0.0;
uniform float head = 0.0;

void fragment() {
	float side = 1.0 - abs(fract(UV.x + 0.5) - 0.5) * 2.0;
	side = 1.0 - side;   // UV.x=0 背脊 → side 0；UV.x=0.5 腹部 → side 1
	vec2 g = vec2(UV.x * scale_u, UV.y * scale_v);
	g.x += mod(floor(g.y), 2.0) * 0.5;
	vec2 f = fract(g) - 0.5;
	float d = length(f * vec2(1.0, 1.25));
	float edge = smoothstep(0.30, 0.52, d);
	// 背部菱形（以背脊線鏡像對稱）
	float wave = abs(fract(UV.y * 0.42) - 0.5) * 2.0;
	float bound = (0.06 + 0.22 * wave) * (1.0 - head);
	float dia = 1.0 - smoothstep(-0.02, 0.02, side - bound);
	float outline = 1.0 - smoothstep(0.0, 0.045, abs(side - bound));
	float spot = 1.0 - smoothstep(0.0, 0.05, abs(side - 0.55) - 0.06 * (1.0 - wave));
	vec3 c = mix(col_back, col_pat, dia);
	c = mix(c, vec3(0.015, 0.035, 0.02), outline * 0.85);
	c = mix(c, col_pat * 0.7, spot * 0.5 * step(side, 0.75));
	float belly = smoothstep(0.66, 0.82, side);
	c = mix(c, col_belly, belly);
	c *= mix(1.0, 0.5, edge * (1.0 - belly * 0.6));
	ALBEDO = c;
	ROUGHNESS = mix(0.38, 0.7, edge);
	SPECULAR = 0.4;
	CLEARCOAT = 0.25;
	CLEARCOAT_ROUGHNESS = 0.35;
	vec3 n = normalize(vec3(f.x * 1.4, f.y * 1.4, 0.55));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
	RIM = 0.12;
	RIM_TINT = 0.7;
	float iri = shimmer * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = vec3(1.0, 0.08, 0.05) * hurt * 1.6 + col_pat * glow * 0.8 + vec3(0.2, 0.6, 1.0) * iri * 0.35;
}
