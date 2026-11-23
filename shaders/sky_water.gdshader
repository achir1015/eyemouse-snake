shader_type sky;
// 水下：上方亮、下方暗的藍綠漸層
uniform vec3 top : source_color = vec3(0.25, 0.6, 0.7);
uniform vec3 deep : source_color = vec3(0.01, 0.08, 0.12);
void sky() {
	float y = EYEDIR.y;
	COLOR = mix(deep, top, smoothstep(-0.6, 0.9, y)) + top * pow(max(y, 0.0), 12.0) * 0.8;
}
