shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.06, 0.27, 0.68, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.15, 0.48, 0.86, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform vec2 splash_center = vec2(-1.95, 4.88);
uniform float cliff_shore_z = 5.88;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	float dist_splash = length(v_world_pos.xz - splash_center);
	float ring_wave = sin(dist_splash * 5.2 - TIME * 4.8) * exp(-dist_splash * 1.45) * 0.024;
	float swell = sin(v_world_pos.x * 1.1 + TIME * 1.6) * cos(v_world_pos.z * 0.9 - TIME * 1.3) * 0.015;
	VERTEX.y += ring_wave + swell;
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	float dist_splash = length(vec2((xz.x - splash_center.x) * 0.8, xz.y - splash_center.y));

	// Deep arctic lake gradient: brighter near impact & shoreline, deeper out in the basin
	float shallow_t = clamp(exp(-dist_splash * 0.75) * 0.75 + smoothstep(cliff_shore_z + 2.2, cliff_shore_z - 0.6, xz.y) * 0.45, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, shallow_t);

	// Drifting surface water shimmer streaks
	float n1 = noise2(vec2(xz.x * 0.85 + TIME * 0.12, xz.y * 0.7 - TIME * 0.48));
	float n2 = noise2(vec2(xz.x * 1.6 - TIME * 0.18, xz.y * 1.3 - TIME * 0.72));
	float shimmer = smoothstep(0.62, 0.88, n1 * 0.6 + n2 * 0.4);
	col = mix(col, shallow_color.rgb * 1.2, shimmer * 0.42);

	// Tight concentric waterfall impact ripples (~1.8-2.2m radius)
	float ripple_wave = sin(dist_splash * 5.6 - TIME * 5.0 + n1 * 1.4);
	float ripple_mask = smoothstep(0.62, 0.96, ripple_wave) * exp(-dist_splash * 1.35);

	// Churning white splash foam right where the waterfall hits the lake
	float impact_foam = exp(-dist_splash * 1.45) * smoothstep(0.24, 0.70, n2 * 0.7 + n1 * 0.3);

	// Soft animated shoreline foam along the cliff base
	float shore_dist = abs(xz.y - cliff_shore_z);
	float shore_foam = (1.0 - smoothstep(0.05, 0.72, shore_dist)) * smoothstep(0.38, 0.78, n1 + sin(TIME * 2.0 + xz.x * 1.8) * 0.12);

	float total_foam = clamp(impact_foam * 1.05 + ripple_mask * 0.42 + shore_foam * 0.42 + shimmer * 0.08, 0.0, 1.0);
	col = mix(col, foam_color.rgb, total_foam);

	ALBEDO = col;
	ROUGHNESS = mix(0.28, 0.62, total_foam);
	SPECULAR = 0.35;
}
