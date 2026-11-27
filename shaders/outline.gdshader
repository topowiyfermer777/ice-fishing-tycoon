shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.08, 0.08, 0.11, 1.0);
uniform float outline_width : hint_range(0.0, 0.06) = 0.012;
uniform bool use_smooth_normal = false;

void vertex() {
	vec3 n = NORMAL;
	if (use_smooth_normal) {
		n = CUSTOM0.xyz * 2.0 - 1.0;
	}
	float len_n = length(n);
	n = len_n > 0.0001 ? n / len_n : NORMAL;

	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cam_dist = max(1.0, -view_pos.z);
	float dist_scale = clamp(cam_dist / 16.5, 0.78, 1.45);

	VERTEX += n * outline_width * dist_scale;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
