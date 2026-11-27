shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 snow_light_color : source_color = vec4(0.96, 0.985, 1.0, 1.0);
uniform vec4 snow_mid_color : source_color = vec4(0.944, 0.972, 0.995, 1.0);
uniform vec4 snow_shadow_color : source_color = vec4(0.86, 0.92, 0.98, 1.0);
uniform float drift_scale = 0.42;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 43.21);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	vec2 p = vec2(xz.x * 0.85 + xz.y * 0.35, xz.y * 1.15 - xz.x * 0.25) * drift_scale;
	float n1 = noise2(p);
	float broad = noise2(xz * 0.14 + vec2(11.3, 4.7));
	float wave = sin(xz.x * 0.55 + xz.y * 0.35 + n1 * 2.8) * 0.5 + 0.5;
	float h = mix(n1 * 0.65 + broad * 0.35, wave, 0.38);

	// Stylized wind-swept snowdrifts matching cliff Mat_SnowCap color (2 noise lookups total)
	vec3 col = mix(snow_shadow_color.rgb, snow_mid_color.rgb, smoothstep(0.18, 0.54, h));
	col = mix(col, snow_light_color.rgb, smoothstep(0.52, 0.86, h * 0.78 + broad * 0.26));

	float bank_band = smoothstep(5.6, 3.85, abs(xz.x + 1.95));
	col = mix(col, snow_shadow_color.rgb * 0.98, bank_band * 0.05);

	ALBEDO = col;
	ROUGHNESS = 0.50;
	SPECULAR = 0.44;
}
