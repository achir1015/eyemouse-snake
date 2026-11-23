shader_type spatial;
// 水底地面：照片材質＋水面折射的光紋（焦散）
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.12;
uniform float caustic = 1.0;
uniform vec3 caustic_col : source_color = vec3(0.7, 0.9, 0.85);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float cau(vec2 p) {
	float t = TIME * 0.6;
	vec2 i = p;
	float c = 1.0;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - 3.5 / float(n + 1));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / 0.005), p.y / (cos(i.y + tt) / 0.005)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}
void fragment() {
	vec2 uv = wp.xz * uv_scale;
	ALBEDO = texture(albedo_tex, uv).rgb;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = 0.8;
	EMISSION = caustic_col * clamp(cau(wp.xz * 0.25), 0.0, 1.0) * caustic * 0.5;
}
