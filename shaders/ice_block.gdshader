shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec4 ice_core_color : source_color = vec4(0.24, 0.64, 0.98, 1.0);
uniform vec4 ice_rim_color : source_color = vec4(0.98, 0.995, 1.0, 1.0);
uniform vec4 edge_contour_color : source_color = vec4(0.18, 0.42, 0.72, 1.0);
uniform vec4 crack_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);

uniform float crack_amount : hint_range(0.0, 1.0) = 0.0;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.005;
uniform float frost_blur : hint_range(0.0, 3.0) = 0.22;
uniform float contour_strength : hint_range(0.0, 1.0) = 0.0;
uniform float white_outline_strength : hint_range(0.0, 1.5) = 1.0;
uniform float white_edge_width : hint_range(0.01, 0.20) = 0.045;

varying vec3 v_local_pos;
varying vec3 v_local_normal;

vec3 hash33(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return fract(sin(p) * 43758.5453123);
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Smooth 3D value noise for organic crystalline refraction ripples
float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

// 3D Voronoi edge distance for crisp crystalline spiderweb cracks
float voronoi_edge(vec3 x) {
	vec3 n = floor(x);
	vec3 f = fract(x);
	vec3 mg = vec3(0.0);
	vec3 mr = vec3(0.0);
	float md = 8.0;

	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				vec3 o = hash33(n + g);
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < md) {
					md = d;
					mr = r;
					mg = g;
				}
			}
		}
	}

	md = 8.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = mg + vec3(float(i), float(j), float(k));
				vec3 o = hash33(n + g);
				vec3 r = g + o - f;
				if (dot(mr - r, mr - r) > 0.00001) {
					md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
				}
			}
		}
	}
	return md;
}

void vertex() {
	v_local_pos = VERTEX;
	v_local_normal = NORMAL;
}

void fragment() {
	vec3 nrm = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float ndv = abs(dot(nrm, view_dir));
	float fresnel = pow(1.0 - clamp(ndv, 0.0, 1.0), 4.0);

	// 12 cube-edge crisp thin white bevel highlights
	vec3 ln = normalize(v_local_normal);
	float axis_max = max(abs(ln.x), max(abs(ln.y), abs(ln.z)));
	float edge_highlight = smoothstep(0.725 + white_edge_width, 0.725, axis_max);

	// Sharp high-contrast white silhouette outline
	float white_rim = smoothstep(0.50, 0.72, fresnel);
	float white_outline = clamp(max(edge_highlight, white_rim) * white_outline_strength, 0.0, 1.0);
	float rim_contour = smoothstep(0.80, 0.95, fresnel) * contour_strength;

	// Crystalline 3D ripple distortion for optical ice refraction
	float nx = noise3(v_local_pos * 5.5 + vec3(1.7, 0.0, 2.3)) - 0.5;
	float ny = noise3(v_local_pos * 5.5 + vec3(4.2, 3.1, 0.8)) - 0.5;
	vec2 ripple = vec2(nx, ny) * 1.45;
	vec2 refract_vec = (nrm.xy * 0.65 + ripple) * refraction_strength * (1.0 + crack_amount * 0.65);
	refract_vec *= (1.0 - max(white_outline * 0.92, rim_contour * 0.92));

	vec2 refracted_uv = clamp(SCREEN_UV + refract_vec, vec2(0.002), vec2(0.998));
	float mip_lod = frost_blur * (0.45 + fresnel * 0.60 + crack_amount * 0.55);
	vec3 bg_refracted = textureLod(screen_tex, refracted_uv, mip_lod).rgb;

	// Subtle icy blue tint on transmitted light
	vec3 ice_transmit = mix(vec3(0.84, 0.94, 1.0), ice_core_color.rgb * 1.4, 0.18);
	vec3 transmitted_bg = bg_refracted * ice_transmit;

	// Surface shading layers
	float surface_opacity = mix(0.12, 0.28, fresnel);
	surface_opacity = max(surface_opacity, white_outline * 0.96);
	surface_opacity = mix(surface_opacity, 0.96, rim_contour);

	vec3 surface_col = mix(ice_core_color.rgb, ice_rim_color.rgb, fresnel * 0.65);
	surface_col = mix(surface_col, ice_rim_color.rgb, white_outline);
	surface_col = mix(surface_col, edge_contour_color.rgb, rim_contour * 0.65);

	vec3 outline_emission = ice_rim_color.rgb * white_outline * (1.0 - rim_contour) * 0.92;

	vec3 crack_emission = vec3(0.0);
	if (crack_amount > 0.01) {
		float d1 = voronoi_edge(v_local_pos * 4.2 + vec3(1.3, 2.7, 0.9));
		float d2 = voronoi_edge(v_local_pos * 8.6 + vec3(4.1, 0.6, 3.2));

		float w1 = mix(0.015, 0.065, crack_amount);
		float main_cracks = 1.0 - smoothstep(0.0, w1, d1);

		float secondary_gate = smoothstep(0.45, 0.75, crack_amount);
		float w2 = mix(0.01, 0.045, crack_amount);
		float sub_cracks = (1.0 - smoothstep(0.0, w2, d2)) * secondary_gate * 0.85;

		float frost = smoothstep(0.75, 1.0, crack_amount) * fresnel * 0.25;
		float crack_mask = clamp((main_cracks + sub_cracks) * smoothstep(0.05, 0.35, crack_amount), 0.0, 1.0);

		surface_col = mix(surface_col, crack_color.rgb, clamp(crack_mask + frost, 0.0, 1.0));
		surface_opacity = clamp(surface_opacity + crack_mask * 0.72 + frost * 0.35, 0.0, 0.98);
		crack_emission = crack_color.rgb * crack_mask * 0.55;
	}

	ALBEDO = surface_col * surface_opacity;
	EMISSION = transmitted_bg * (1.0 - surface_opacity) + outline_emission + crack_emission;
	ALPHA = 1.0;
	ROUGHNESS = mix(0.08, 0.25, white_outline);
	SPECULAR = mix(0.72, 0.30, rim_contour);
}
