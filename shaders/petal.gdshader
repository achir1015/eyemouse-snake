shader_type spatial;
// 荷花瓣：底部白、尖端粉紅，透光
void fragment() {
	float tip = smoothstep(0.35, 1.0, UV.y);
	ALBEDO = mix(vec3(1.0, 0.95, 0.92), vec3(0.95, 0.45, 0.62), tip);
	ROUGHNESS = 0.55;
	BACKLIGHT = vec3(0.6, 0.3, 0.35);
	RIM = 0.3;
}
