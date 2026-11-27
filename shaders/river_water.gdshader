shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.06, 0.28, 0.72, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.50, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform float flow_speed = 1.65;
uniform float river_half_width = 1.95;
uniform float river_center_x = -1.95;
uniform float dam_z = 3.95;
uniform float dam_built = 0.0;
uniform float cliff_z = 4.4;
uniform float source_z = -15.0;

varying vec3 world_pos;

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
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(world_pos.x * 3.0 + TIME * 2.2) * cos(world_pos.z * 2.0 - TIME * 3.1) * 0.015;
	VERTEX.y += wave;
}

void fragment() {
	float dist_from_center = abs(world_pos.x - river_center_x);
	float edge_t = clamp(dist_from_center / river_half_width, 0.0, 1.0);

	// Base water gradient: brighter near banks, deeper in center
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, pow(edge_t, 1.6) * 0.85);

	// Animated flow streaks moving downstream (+Z)
	vec2 flow_uv1 = vec2(world_pos.x * 2.2, world_pos.z * 0.55 - TIME * flow_speed);
	vec2 flow_uv2 = vec2(world_pos.x * 3.8 + 1.7, world_pos.z * 0.9 - TIME * flow_speed * 1.35);
	float n1 = noise2(flow_uv1);
	float n2 = noise2(flow_uv2);
	float streak = smoothstep(0.68, 0.92, n1 * 0.65 + n2 * 0.35);
	col = mix(col, shallow_color.rgb * 1.18, streak * 0.45);

	// Shore foam tightened along both river banks
	float bank_noise = noise2(vec2(world_pos.x * 4.0, world_pos.z * 2.5 - TIME * flow_speed * 0.9));
	float shore_foam = smoothstep(0.88, 0.99, edge_t + bank_noise * 0.08);

	// Waterfall brink foam near Z = cliff_z (soft blend into waterfall top)
	float brink_t = smoothstep(cliff_z - 0.95, cliff_z, world_pos.z);
	float brink_foam = brink_t * smoothstep(0.35, 0.8, n2);

	// Upper glacier spring foam near Z = source_z
	float source_foam = (1.0 - smoothstep(0.0, 1.35, world_pos.z - source_z)) * smoothstep(0.28, 0.76, n1 * 0.55 + n2 * 0.45);

	// Log dam foam when dam is built
	float dam_dist = abs(world_pos.z - dam_z);
	float dam_foam = dam_built * (1.0 - smoothstep(0.05, 0.42, dam_dist)) * smoothstep(0.25, 0.75, n1);

	float total_foam = clamp(shore_foam * 0.72 + brink_foam * 0.55 + source_foam * 0.85 + dam_foam * 0.9 + streak * 0.12, 0.0, 1.0);
	col = mix(col, foam_color.rgb, total_foam);

	ALBEDO = col;
	ROUGHNESS = mix(0.38, 0.65, total_foam);
	SPECULAR = 0.28;
}
