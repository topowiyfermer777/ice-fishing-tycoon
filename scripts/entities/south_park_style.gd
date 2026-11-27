extends RefCounted
class_name SouthParkStyle

enum CharacterId {
	STAN,
	KYLE,
	CARTMAN,
	KENNY,
}

const PALETTES := {
	CharacterId.STAN: {
		"parka": Color(0.47, 0.29, 0.17, 1.0),
		"hood": Color(0.14, 0.40, 0.75, 1.0),
		"hood_fur": Color(0.84, 0.16, 0.21, 1.0),
		"trim": Color(0.32, 0.19, 0.11, 1.0),
		"mitten": Color(0.84, 0.16, 0.21, 1.0),
		"pants": Color(0.16, 0.33, 0.60, 1.0),
		"hair": Color(0.09, 0.08, 0.08, 1.0),
	},
	CharacterId.KYLE: {
		"parka": Color(0.94, 0.42, 0.10, 1.0),
		"hood": Color(0.22, 0.68, 0.20, 1.0),
		"hood_fur": Color(0.10, 0.42, 0.13, 1.0),
		"trim": Color(0.76, 0.31, 0.07, 1.0),
		"mitten": Color(0.22, 0.68, 0.20, 1.0),
		"pants": Color(0.17, 0.34, 0.33, 1.0),
		"hair": Color(0.78, 0.25, 0.09, 1.0),
	},
	CharacterId.CARTMAN: {
		"parka": Color(0.86, 0.15, 0.19, 1.0),
		"hood": Color(0.15, 0.74, 0.80, 1.0),
		"hood_fur": Color(0.98, 0.83, 0.16, 1.0),
		"trim": Color(0.68, 0.10, 0.14, 1.0),
		"mitten": Color(0.98, 0.83, 0.16, 1.0),
		"pants": Color(0.38, 0.25, 0.16, 1.0),
		"hair": Color(0.30, 0.19, 0.12, 1.0),
	},
	CharacterId.KENNY: {
		"parka": Color(0.96, 0.44, 0.08, 1.0),
		"hood": Color(0.96, 0.44, 0.08, 1.0),
		"hood_fur": Color(0.38, 0.21, 0.11, 1.0),
		"trim": Color(0.38, 0.21, 0.11, 1.0),
		"mitten": Color(0.38, 0.21, 0.11, 1.0),
		"pants": Color(0.96, 0.44, 0.08, 1.0),
		"hair": Color(0.92, 0.78, 0.34, 1.0),
	},
}

static var _material_cache: Dictionary = {}

static func apply_to_customer(model_root: Node, char_id: int) -> void:
	if model_root == null:
		return
	var palette: Dictionary = PALETTES.get(char_id, PALETTES[CharacterId.STAN])
	_apply_recursive(model_root, char_id, palette)

static func attach_hat(rig: CharacterRig, char_id: int) -> void:
	if char_id == CharacterId.KENNY or rig == null or rig.skeleton == null:
		return
	var existing := rig.skeleton.get_node_or_null("Attach_SP_Hat")
	if existing != null:
		existing.queue_free()

	var attach := BoneAttachment3D.new()
	attach.name = "Attach_SP_Hat"
	attach.bone_name = "head"
	rig.skeleton.add_child(attach)

	var hat_root := Node3D.new()
	hat_root.name = "Hat"
	attach.add_child(hat_root)

	var palette: Dictionary = PALETTES.get(char_id, PALETTES[CharacterId.STAN])
	var main_mat := _make_hat_mat(palette["hood"] as Color)
	var accent_mat := _make_hat_mat(palette["hood_fur"] as Color)

	if char_id == CharacterId.STAN:
		_build_beanie(hat_root, main_mat, accent_mat, 0.110, 0.088, 0.210, 0.095, 0.120, 0.044, 0.326)
	elif char_id == CharacterId.CARTMAN:
		_build_beanie(hat_root, main_mat, accent_mat, 0.112, 0.082, 0.208, 0.096, 0.122, 0.046, 0.320)
	elif char_id == CharacterId.KYLE:
		_build_ushanka(hat_root, main_mat, accent_mat)

	OutlineHelper.apply(hat_root, OutlineConfig.Category.CHARACTER, false)

static func get_scale(char_id: int, compact: bool = false) -> Vector3:
	if char_id == CharacterId.CARTMAN:
		return Vector3(1.14, 0.96, 1.14) if compact else Vector3(1.24, 0.95, 1.24)
	return Vector3.ONE

static func _make_hat_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	return mat

static func _build_beanie(
	parent: Node3D,
	dome_mat: StandardMaterial3D,
	trim_mat: StandardMaterial3D,
	dome_r: float,
	dome_h: float,
	base_y: float,
	cuff_inner: float,
	cuff_outer: float,
	pom_r: float,
	pom_y: float
) -> void:
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = dome_r
	dome_mesh.height = dome_h
	dome_mesh.is_hemisphere = true
	var dome := MeshInstance3D.new()
	dome.name = "BeanieDome"
	dome.mesh = dome_mesh
	dome.set_surface_override_material(0, dome_mat)
	dome.position = Vector3(0.0, base_y, 0.012)
	dome.scale = Vector3(1.0, 1.0, 0.88)
	parent.add_child(dome)

	var cuff_mesh := TorusMesh.new()
	cuff_mesh.inner_radius = cuff_inner
	cuff_mesh.outer_radius = cuff_outer
	var cuff := MeshInstance3D.new()
	cuff.name = "BeanieCuff"
	cuff.mesh = cuff_mesh
	cuff.set_surface_override_material(0, trim_mat)
	cuff.position = Vector3(0.0, base_y, 0.012)
	cuff.scale = Vector3(1.0, 1.25, 0.88)
	parent.add_child(cuff)

	var pom_mesh := SphereMesh.new()
	pom_mesh.radius = pom_r
	pom_mesh.height = pom_r * 2.0
	pom_mesh.is_hemisphere = false
	var pom := MeshInstance3D.new()
	pom.name = "BeaniePom"
	pom.mesh = pom_mesh
	pom.set_surface_override_material(0, trim_mat)
	pom.position = Vector3(0.0, pom_y, 0.012)
	parent.add_child(pom)

static func _build_ushanka(parent: Node3D, main_mat: StandardMaterial3D, front_mat: StandardMaterial3D) -> void:
	var crown_mesh := BoxMesh.new()
	crown_mesh.size = Vector3(0.214, 0.096, 0.192)
	var crown := MeshInstance3D.new()
	crown.name = "UshankaCrown"
	crown.mesh = crown_mesh
	crown.set_surface_override_material(0, main_mat)
	crown.position = Vector3(0.0, 0.248, 0.012)
	parent.add_child(crown)

	var top_mesh := SphereMesh.new()
	top_mesh.radius = 0.108
	top_mesh.height = 0.036
	top_mesh.is_hemisphere = true
	var top_cap := MeshInstance3D.new()
	top_cap.name = "UshankaTop"
	top_cap.mesh = top_mesh
	top_cap.set_surface_override_material(0, main_mat)
	top_cap.position = Vector3(0.0, 0.284, 0.012)
	top_cap.scale = Vector3(1.0, 1.0, 0.90)
	parent.add_child(top_cap)

	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(0.204, 0.082, 0.028)
	var front := MeshInstance3D.new()
	front.name = "UshankaFront"
	front.mesh = front_mesh
	front.set_surface_override_material(0, front_mat)
	front.position = Vector3(0.0, 0.244, 0.108)
	parent.add_child(front)

	var flap_mesh := BoxMesh.new()
	flap_mesh.size = Vector3(0.034, 0.138, 0.096)
	for side in [-1.0, 1.0]:
		var flap := MeshInstance3D.new()
		flap.name = "UshankaEarL" if side < 0.0 else "UshankaEarR"
		flap.mesh = flap_mesh
		flap.set_surface_override_material(0, main_mat)
		flap.position = Vector3(0.118 * side, 0.186, 0.010)
		flap.rotation_degrees = Vector3(0.0, 0.0, -14.0 * side)
		parent.add_child(flap)

static func _apply_recursive(node: Node, char_id: int, palette: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var lname := mi.name.to_lower()
		if char_id != CharacterId.KENNY and (lname.contains("hood") or lname.contains("hair")):
			mi.visible = false
			return
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var slot := _match_slot(lname)
			if not slot.is_empty() and palette.has(slot):
				var base_mat: Material = mi.get_active_material(0)
				if base_mat != null:
					var key := "%d_%s_%d" % [char_id, slot, base_mat.get_rid().get_id()]
					var cached: Material = _material_cache.get(key)
					if cached == null:
						var dup: Material = base_mat.duplicate()
						if dup is BaseMaterial3D:
							(dup as BaseMaterial3D).albedo_color = palette[slot] as Color
						_material_cache[key] = dup
						cached = dup
					mi.set_surface_override_material(0, cached)
	for child in node.get_children():
		_apply_recursive(child, char_id, palette)

static func _match_slot(lname: String) -> String:
	if lname.contains("parka_body") or lname.contains("arm_l") or lname.contains("arm_r"):
		return "parka"
	if lname.contains("hood_fur"):
		return "hood_fur"
	if lname.contains("hood"):
		return "hood"
	if lname.contains("cuff") or lname.contains("parka_hem"):
		return "trim"
	if lname.contains("mitten"):
		return "mitten"
	if lname.contains("pants") or lname.contains("leg"):
		return "pants"
	if lname.contains("hair"):
		return "hair"
	return ""
