extends RefCounted
class_name OutlineHelper

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

static var _smoothed_mesh_cache: Dictionary = {}
static var _outline_mat_cache: Dictionary = {}
static var _outlined_surface_cache: Dictionary = {}

static func apply(root: Node, category: int, smooth_normals: bool = false) -> void:
	if root == null or category == OutlineConfig.Category.NONE:
		return
	var width := OutlineConfig.get_width(category)
	if width <= 0.0:
		return
	var color := OutlineConfig.get_color(category)
	_apply_recursive(root, color, width, smooth_normals)

static func _apply_recursive(node: Node, color: Color, width: float, smooth_normals: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and not OutlineConfig.should_skip_mesh(mi.name):
			var is_skinned := mi.skin != null or mi.get_parent() is Skeleton3D
			var use_smooth := smooth_normals and not is_skinned
			if use_smooth:
				mi.mesh = _get_or_bake_smooth_mesh(mi.mesh)

			var outline_mat := _get_outline_material(color, width, use_smooth)

			var surf_count := mi.mesh.get_surface_count()
			for s in range(surf_count):
				var base_mat := mi.get_active_material(s)
				if base_mat == null:
					var std_key := "%d_%s_%.4f_%s" % [0, color.to_html(), width, str(use_smooth)]
					var cached_std: Material = _outlined_surface_cache.get(std_key)
					if cached_std == null:
						var std := StandardMaterial3D.new()
						std.next_pass = outline_mat
						_outlined_surface_cache[std_key] = std
						cached_std = std
					mi.set_surface_override_material(s, cached_std)
				elif base_mat.resource_local_to_scene:
					var dup := base_mat.duplicate()
					dup.next_pass = outline_mat
					mi.set_surface_override_material(s, dup)
				else:
					var mat_key := "%d_%s_%.4f_%s" % [base_mat.get_rid().get_id(), color.to_html(), width, str(use_smooth)]
					var cached_mat: Material = _outlined_surface_cache.get(mat_key)
					if cached_mat == null:
						var dup := base_mat.duplicate()
						dup.next_pass = outline_mat
						_outlined_surface_cache[mat_key] = dup
						cached_mat = dup
					mi.set_surface_override_material(s, cached_mat)

	for child in node.get_children():
		_apply_recursive(child, color, width, smooth_normals)

static func _get_outline_material(color: Color, width: float, use_smooth: bool) -> ShaderMaterial:
	var key := "%s_%.4f_%s" % [color.to_html(), width, str(use_smooth)]
	var cached: ShaderMaterial = _outline_mat_cache.get(key)
	if cached != null:
		return cached
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_width", width)
	mat.set_shader_parameter("use_smooth_normal", use_smooth)
	_outline_mat_cache[key] = mat
	return mat

static func _get_or_bake_smooth_mesh(src_mesh: Mesh) -> Mesh:
	var key := src_mesh.get_rid().get_id()
	if _smoothed_mesh_cache.has(key):
		return _smoothed_mesh_cache[key]

	if not (src_mesh is ArrayMesh):
		return src_mesh

	var arr_src := src_mesh as ArrayMesh
	var out_mesh := ArrayMesh.new()
	var surf_count := arr_src.get_surface_count()

	for s in range(surf_count):
		var arrays := arr_src.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if verts.is_empty() or norms.is_empty():
			out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat_fallback := arr_src.surface_get_material(s)
			if mat_fallback != null:
				out_mesh.surface_set_material(s, mat_fallback)
			continue

		# Detect inward-facing normals & reversed triangle winding (e.g. Tuna_v2 body)
		var center := Vector3.ZERO
		for v in verts:
			center += v
		center /= float(verts.size())
		var dot_sum := 0.0
		for i in range(verts.size()):
			dot_sum += (verts[i] - center).dot(norms[i])
		var flip_winding := (dot_sum / float(verts.size())) < -0.005

		var accum: Dictionary = {}
		for i in range(verts.size()):
			var v := verts[i]
			var q := Vector3i(roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0))
			var n_dir := -norms[i] if flip_winding else norms[i]
			if accum.has(q):
				accum[q] += n_dir
			else:
				accum[q] = n_dir

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)

		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		var emit_vertex := func(idx: int) -> void:
			var v := verts[idx]
			var q := Vector3i(roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0))
			var n_out := -norms[idx] if flip_winding else norms[idx]
			var sn: Vector3 = accum.get(q, n_out)
			if sn.length_squared() > 0.00001:
				sn = sn.normalized()
			else:
				sn = n_out
			st.set_normal(n_out)
			if idx < uvs.size():
				st.set_uv(uvs[idx])
			if idx < colors.size():
				st.set_color(colors[idx])
			st.set_custom(0, Color(sn.x * 0.5 + 0.5, sn.y * 0.5 + 0.5, sn.z * 0.5 + 0.5, 1.0))
			st.add_vertex(v)

		if not indices.is_empty():
			var t := 0
			while t + 2 < indices.size():
				if flip_winding:
					emit_vertex.call(indices[t])
					emit_vertex.call(indices[t + 2])
					emit_vertex.call(indices[t + 1])
				else:
					emit_vertex.call(indices[t])
					emit_vertex.call(indices[t + 1])
					emit_vertex.call(indices[t + 2])
				t += 3
		else:
			var t := 0
			while t + 2 < verts.size():
				if flip_winding:
					emit_vertex.call(t)
					emit_vertex.call(t + 2)
					emit_vertex.call(t + 1)
				else:
					emit_vertex.call(t)
					emit_vertex.call(t + 1)
					emit_vertex.call(t + 2)
				t += 3

		var mat := arr_src.surface_get_material(s)
		if mat != null:
			st.set_material(mat)
		st.commit(out_mesh)

	_smoothed_mesh_cache[key] = out_mesh
	return out_mesh
