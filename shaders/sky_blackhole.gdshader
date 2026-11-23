shader_type sky;
// 黑洞：沿光線逐步計算重力彎曲（牛頓近似），畫出事件視界、扭曲的吸積盤（都卜勒增亮）與被透鏡化的銀河背景。
render_mode use_quarter_res_pass;
uniform sampler2D stars : source_color, filter_linear;
uniform vec3 bh_dir = vec3(0.0, 0.08, -1.0);
uniform float bh_dist = 60.0;
uniform float rs = 3.0;          // 史瓦西半徑
uniform vec3 disk_n = vec3(0.12, 1.0, 0.18);

vec3 star_bg(vec3 d) {
	vec2 uv = vec2(atan(d.z, d.x) / (2.0 * PI) + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
	return texture(stars, uv).rgb * 0.9;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = vec3(0.0);
	if (AT_QUARTER_RES_PASS || AT_CUBEMAP_PASS) {
		vec3 c = normalize(bh_dir) * bh_dist;
		vec3 dn = normalize(disk_n);
		vec3 p = vec3(0.0);
		vec3 v = d;
		vec3 acc = vec3(0.0);
		float alpha = 1.0;
		bool hit = false;
		float near = dot(c, d);
		// 只有朝向黑洞附近的光線才需要逐步計算
		if (length(c - d * near) < rs * 14.0 && near > 0.0) {
			p = d * max(near - rs * 16.0, 0.0);
			float step_len = rs * 0.35;
			for (int i = 0; i < 110; i++) {
				vec3 r = c - p;
				float dist = length(r);
				if (dist < rs) { hit = true; break; }
				v = normalize(v + r / (dist * dist * dist) * rs * 1.5 * step_len);
				vec3 np = p + v * step_len;
				float s0 = dot(p - c, dn);
				float s1 = dot(np - c, dn);
				if (s0 * s1 < 0.0) {
					vec3 q = mix(p, np, s0 / (s0 - s1)) - c;
					float rr = length(q) / rs;
					if (rr > 2.6 && rr < 9.0) {
						float tt = (rr - 2.6) / 6.4;
						vec3 hot = mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.45, 0.12), tt);
						vec3 tang = normalize(cross(dn, q));
						float dop = 1.0 + 0.6 * dot(tang, -v);
						float ring = 0.75 + 0.25 * sin(rr * 9.0);
						float dens = smoothstep(0.0, 0.1, tt) * (1.0 - smoothstep(0.7, 1.0, tt));
						float a = dens * 0.85;
						acc += alpha * a * hot * dop * dop * ring * 2.6;
						alpha *= 1.0 - a;
					}
				}
				p = np;
				if (dot(p - c, v) > rs * 18.0) break;
			}
		}
		col = acc + (hit ? vec3(0.0) : star_bg(v) * alpha);
		COLOR = col;
	} else {
		COLOR = QUARTER_RES_COLOR.rgb;
	}
}
