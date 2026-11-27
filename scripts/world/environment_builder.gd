extends Node3D
class_name EnvironmentBuilder

const SKIP_PROP_OUTLINE := ["cliff", "mound", "icedecor"]
const NO_COLLIDER_PROPS := ["snowgrass", "barebush", "snowmound"]
const NO_SHADOW_PROPS := ["snowgrass", "barebush", "snowmound", "icedecor"]

var _cliff_wall_mat: StandardMaterial3D
var _pine_collider_shape: CylinderShape3D
var _cliff_collider_shape: BoxShape3D

func _ready() -> void:
	_cliff_wall_mat = StandardMaterial3D.new()
	_cliff_wall_mat.albedo_color = Color(0.38, 0.48, 0.62, 1.0)
	_cliff_wall_mat.roughness = 0.82
	_cliff_wall_mat.metallic = 0.02

	_pine_collider_shape = CylinderShape3D.new()
	_pine_collider_shape.radius = 0.30
	_pine_collider_shape.height = 2.2

	_cliff_collider_shape = BoxShape3D.new()
	_cliff_collider_shape.size = Vector3(2.0, 1.5, 2.0)

	_setup_cliff_group(get_node_or_null("Cliffs"), true)
	_setup_cliff_group(get_node_or_null("LowerCliffs"), true)
	_setup_cliff_group(get_node_or_null("SideCliffs"), false)
	_setup_cliff_group(get_node_or_null("RiverSource"), true)

	var pines := get_node_or_null("Pines")
	if pines != null:
		OutlineHelper.apply(pines, OutlineConfig.Category.ENVIRONMENT, true)
		for p in pines.get_children():
			_attach_collider(p, _pine_collider_shape, Vector3(0.0, 1.1, 0.0))

	var props := get_node_or_null("Props")
	if props != null:
		for c in props.get_children():
			var lname := c.name.to_lower()
			var skip_outline := false
			for key in SKIP_PROP_OUTLINE:
				if lname.contains(key):
					skip_outline = true
					break
			if not skip_outline:
				OutlineHelper.apply(c, OutlineConfig.Category.ENV_PROP, true)

			if _matches_any(lname, NO_SHADOW_PROPS):
				_disable_shadows_recursive(c)

			if not _matches_any(lname, NO_COLLIDER_PROPS):
				_attach_prop_collider(c, lname)

func _setup_cliff_group(group_node: Node, disable_shadows: bool = false) -> void:
	if group_node == null:
		return
	for cliff in group_node.get_children():
		_color_cliff_walls(cliff)
		if disable_shadows:
			_disable_shadows_recursive(cliff)
		_attach_collider(cliff, _cliff_collider_shape, Vector3(0.0, 0.75, 0.0))

func _color_cliff_walls(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(s)
				if mat != null and mat.resource_name.to_lower().contains("cliffwall"):
					mi.set_surface_override_material(s, _cliff_wall_mat)
	for child in node.get_children():
		_color_cliff_walls(child)

func _attach_prop_collider(prop: Node, lname: String) -> void:
	if lname.contains("snowboulder"):
		var sh := SphereShape3D.new()
		sh.radius = 0.40
		_attach_collider(prop, sh, Vector3(0.0, 0.32, 0.0))
	elif lname.contains("rockcluster"):
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.84, 0.56, 0.64)
		_attach_collider(prop, sh, Vector3(0.0, 0.28, 0.0))
	elif lname.contains("logpile"):
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.95, 0.65, 0.95)
		_attach_collider(prop, sh, Vector3(0.0, 0.32, 0.0))
	elif lname.contains("woodcrate") or lname.contains("icedecor"):
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.75, 0.75, 0.75)
		_attach_collider(prop, sh, Vector3(0.0, 0.375, 0.0))
	elif lname.contains("woodbarrel"):
		var sh := CylinderShape3D.new()
		sh.radius = 0.36
		sh.height = 0.78
		_attach_collider(prop, sh, Vector3(0.0, 0.39, 0.0))
	elif lname.contains("campfire"):
		var sh := CylinderShape3D.new()
		sh.radius = 0.55
		sh.height = 0.60
		_attach_collider(prop, sh, Vector3(0.0, 0.30, 0.0))

func _attach_collider(parent_node: Node, shape: Shape3D, local_offset: Vector3) -> void:
	if parent_node.get_node_or_null("EnvCollider") != null:
		return
	var sb := StaticBody3D.new()
	sb.name = "EnvCollider"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = local_offset
	sb.add_child(cs)
	parent_node.add_child(sb)

func _disable_shadows_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows_recursive(child)

func _matches_any(text: String, keywords: Array) -> bool:
	for k in keywords:
		if text.contains(k):
			return true
	return false
