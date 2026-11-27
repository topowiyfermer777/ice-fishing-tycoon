shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.06, 0.28, 0.72, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.50, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform float flow_speed = 1.65;
uniform float fall_speed = 2.85;
uniform float river_half_width = 1.95;
uniform float river_center_x = -1.95;

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
	// Smooth parabolic outward cascade curve starting tangent to the river surface
	float t = clamp(UV.y, 0.0, 1.0);
	float curve_z = t * t * 0.48;
	float ripple = sin(UV.x * 14.0 + TIME * 4.5) * 0.012 * t;
	VERTEX.z += curve_z + ripple;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	float dist_from_center = abs(v_world_pos.x - river_center_x);
	float edge_t = clamp(dist_from_center / river_half_width, 0.0, 1.0);

	// Match river water gradient at top and brighten subtly into the cascade
	vec3 base_col = mix(deep_color.rgb, shallow_color.rgb, pow(edge_t, 1.6) * 0.85);
	base_col = mix(base_col, shallow_color.rgb * 1.06, smoothstep(0.15, 0.85, t) * 0.35);

	// Continuity with river world-space X streaks and smoothly accelerating flow speed
	float local_scroll = TIME * mix(flow_speed, fall_speed, smoothstep(0.0, 0.65, t));
	vec2 uv1 = vec2(v_world_pos.x * 2.2, UV.y * 2.1 - local_scroll);
	vec2 uv2 = vec2(v_world_pos.x * 3.8 + 1.7, UV.y * 3.4 - local_scroll * 1.35);
	float n1 = noise2(uv1);
	float n2 = noise2(uv2);

	float river_streak = smoothstep(0.68, 0.92, n1 * 0.65 + n2 * 0.35);
	float fall_streak = smoothstep(0.46, 0.86, n1 * 0.58 + n2 * 0.42);
	float streaks = mix(river_streak, fall_streak, smoothstep(0.0, 0.45, t));
	base_col = mix(base_col, shallow_color.rgb * 1.18, streaks * 0.45);

	// Soft crest blend matching river brink foam + bottom plunge foam
	float shore_foam = smoothstep(0.88, 0.99, edge_t + n1 * 0.08) * 0.70;
	float crest_foam = smoothstep(0.35, 0.80, n2) * (1.0 - smoothstep(0.0, 0.42, t)) * 0.55;
	float bottom_foam = smoothstep(0.62, 0.96, t) * (0.45 + 0.55 * n2);

	float total_foam = clamp(streaks * mix(0.12, 0.52, t) + shore_foam + crest_foam + bottom_foam * 0.92, 0.0, 1.0);
	vec3 col = mix(base_col, foam_color.rgb, total_foam);

	float top_feather = smoothstep(0.0, 0.08, t);
	float alpha = mix(0.95, 1.0, total_foam) * mix(0.88, 1.0, top_feather) * (1.0 - smoothstep(0.93, 1.0, t) * 0.20);

	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = mix(0.36, 0.64, total_foam);
	SPECULAR = 0.28;
}
