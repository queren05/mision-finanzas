shader_type spatial;
// lava que fluye despacio y late: color + brillo propio
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D emit : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale = 0.35;
uniform float glow = 3.0;
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = wp.xz * scale + vec2(TIME * 0.012, TIME * 0.007);
	vec2 uv2 = wp.xz * scale * 0.6 - vec2(TIME * 0.009, -TIME * 0.011);
	vec3 c = texture(tex, uv).rgb;
	vec3 e = max(texture(emit, uv).rgb, texture(emit, uv2).rgb * 0.8);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + wp.x * 0.4);
	ALBEDO = c * 0.4;
	ROUGHNESS = 0.6;
	EMISSION = e * glow * pulse;
}
