extends Node3D
class_name IceBlock

signal broken(block: IceBlock, is_giant: bool, world_pos: Vector3)
signal fell_off_waterfall(block: IceBlock)

const ICE_INTACT_SCENE := preload("res://exports/glb/Food_And_Ice/IceCube0.glb")
const ICE_SHADER := preload("res://shaders/ice_block.gdshader")

var is_giant: bool = false
var hp: int = 4
var max_hp: int = 4
var radius: float = 0.54
var drift_speed: float = 0.85
var is_falling: bool = false
var in_lake: bool = false
var reserved_workers: int = 0
var dam_z: float = GameState.DAM_Z
var cliff_z: float = GameState.CLIFF_Z
var damage_stage: int = 0

static var _lake_ice_mat: StandardMaterial3D

var _intact_node: Node3D
var _ice_body: MeshInstance3D
var _ice_mat: ShaderMaterial
var _contact_shadow: MeshInstance3D
var _collider_shape: CollisionShape3D
var _visual_root: Node3D
var _vfx: VfxManager
var _bob_phase: float = 0.0
var _fall_vel_y: float = 0.0
var _shake_time: float = 0.0
var _base_scale: float = 1.0
var _lake_drift_vel := Vector2.ZERO
var _push_vel := Vector2.ZERO

func setup(giant: bool, vfx: VfxManager, p_dam_z: float = GameState.DAM_Z, p_cliff_z: float = GameState.CLIFF_Z) -> void:
	is_giant = giant
	_vfx = vfx
	dam_z = p_dam_z
	cliff_z = p_cliff_z
	max_hp = GameState.GIANT_ICE_HP if giant else GameState.NORMAL_ICE_HP
	hp = max_hp
	_base_scale = 1.72 if giant else 1.0
	radius = 0.55 * _base_scale
	drift_speed = 0.62 if giant else 0.86
	_bob_phase = randf() * TAU

func _ready() -> void:
	_visual_root = get_node_or_null("VisualRoot") as Node3D
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "VisualRoot"
		add_child(_visual_root)

	_intact_node = _visual_root.get_node_or_null("IntactIce") as Node3D
	if _intact_node == null:
		_intact_node = ICE_INTACT_SCENE.instantiate() as Node3D
		_intact_node.name = "IntactIce"
		_visual_root.add_child(_intact_node)

	var old_cracked := _visual_root.get_node_or_null("CrackedIce")
	if old_cracked != null:
		old_cracked.visible = false
		old_cracked.queue_free()

	_setup_ice_shader(_intact_node)
	_outline_inner_tuna_only(_intact_node)
	_intact_node.visible = true
	_update_damage_stage()

	_create_contact_shadow()

	var collider := get_node_or_null("IceCollider") as CollisionObject3D
	if collider != null:
		collider.scale = Vector3.ONE * _base_scale
		_collider_shape = collider.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if _collider_shape != null and (is_falling or in_lake):
			_collider_shape.disabled = true

	var target := Vector3.ONE * _base_scale
	_visual_root.scale = target * 0.1
	_visual_root.create_tween().tween_property(_visual_root, "scale", target, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_contact_shadow() -> void:
	_contact_shadow = MeshInstance3D.new()
	_contact_shadow.name = "ContactShadow"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.22, 1.22) * _base_scale
	_contact_shadow.mesh = pm
	_contact_shadow.position = Vector3(0.0, 0.025, 0.0)

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.03, 0.14, 0.38, 0.52), Color(0.03, 0.14, 0.38, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.95, 0.5)
	tex.width = 64
	tex.height = 64

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	_contact_shadow.material_override = mat
	add_child(_contact_shadow)

func _setup_ice_shader(root: Node) -> void:
	var body := _find_mesh_by_name(root, "IceCube0_Body")
	_ice_body = body
	if body != null:
		_ice_mat = ShaderMaterial.new()
		_ice_mat.shader = ICE_SHADER
		_ice_mat.set_shader_parameter("crack_amount", 0.0)
		body.material_override = _ice_mat

static func _get_lake_ice_material() -> StandardMaterial3D:
	if _lake_ice_mat == null:
		_lake_ice_mat = StandardMaterial3D.new()
		_lake_ice_mat.albedo_color = Color(0.62, 0.86, 1.0, 0.72)
		_lake_ice_mat.roughness = 0.18
		_lake_ice_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_lake_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _lake_ice_mat

func _find_mesh_by_name(root: Node, target_name: String) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == target_name:
		return root as MeshInstance3D
	for c in root.get_children():
		var found := _find_mesh_by_name(c, target_name)
		if found != null:
			return found
	return null

func _process(delta: float) -> void:
	if in_lake:
		_bob_phase += delta * 2.1
		_visual_root.position.x = 0.0
		_visual_root.position.y = sin(_bob_phase) * 0.045 - 0.14
		_visual_root.rotation.x = lerpf(_visual_root.rotation.x, 0.0, minf(1.0, delta * 3.5))
		_visual_root.rotation.z = sin(_bob_phase * 0.75) * 0.04
		global_position.x += _lake_drift_vel.x * delta
		global_position.z += _lake_drift_vel.y * delta
		_lake_drift_vel = _lake_drift_vel.lerp(Vector2.ZERO, minf(1.0, delta * 1.35))
		global_position.y = lerpf(global_position.y, GameState.LAKE_Y, minf(1.0, delta * 6.0))
		return

	if is_falling:
		_fall_vel_y -= 18.0 * delta
		global_position.y += _fall_vel_y * delta
		global_position.z += drift_speed * 1.45 * delta
		_visual_root.rotate_x(2.2 * delta)
		if global_position.y <= GameState.LAKE_Y + 0.05:
			if _vfx != null:
				_vfx.spawn_water_splash(Vector3(global_position.x, GameState.LAKE_Y + 0.04, global_position.z), 7, 1.4 if is_giant else 0.95)
			enter_lake(GameState.LAKE_Y, false)
			fell_off_waterfall.emit(self)
		return

	_bob_phase += delta * 2.4
	_visual_root.position.y = sin(_bob_phase) * 0.035 - 0.14
	_visual_root.rotation.z = sin(_bob_phase * 0.8) * 0.035

	if _shake_time > 0.0:
		_shake_time -= delta
		_visual_root.position.x = sin(_shake_time * 55.0) * 0.06
	elif damage_stage >= 3:
		_visual_root.position.x = sin(Time.get_ticks_msec() * 0.045) * 0.015
	else:
		_visual_root.position.x = 0.0

	var next_z := global_position.z + (drift_speed + _push_vel.y) * delta
	global_position.x = clampf(global_position.x + _push_vel.x * delta, -3.35, -0.52)
	_push_vel = _push_vel.lerp(Vector2.ZERO, minf(1.0, delta * 5.2))
	if GameState.dam_built:
		var stop_z := dam_z - radius - 0.08
		if next_z >= stop_z:
			next_z = stop_z
	else:
		if next_z >= cliff_z - 0.12:
			is_falling = true
			if _collider_shape != null:
				_collider_shape.disabled = true
			if is_instance_valid(_contact_shadow):
				_contact_shadow.visible = false
			_fall_vel_y = -0.8
			if _vfx != null:
				_vfx.spawn_water_splash(Vector3(global_position.x, GameState.WATER_Y, global_position.z), 6, 1.2)
	global_position.z = next_z

func apply_push_impulse(impulse: Vector2) -> void:
	_push_vel += impulse
	var max_spd := 2.4 if is_giant else 3.4
	if _push_vel.length() > max_spd:
		_push_vel = _push_vel.normalized() * max_spd

func damp_forward_push() -> void:
	if _push_vel.y > 0.0:
		_push_vel.y = 0.0

func enter_lake(lake_y: float, immediate: bool = false) -> void:
	is_falling = false
	in_lake = true
	hp = 0
	if _collider_shape != null:
		_collider_shape.disabled = true
	if is_instance_valid(_contact_shadow):
		_contact_shadow.visible = false
	_disable_shadows_recursive(self)
	if is_instance_valid(_ice_body):
		_ice_body.material_override = _get_lake_ice_material()
	if immediate:
		global_position.y = lake_y
		_lake_drift_vel = Vector2.ZERO
		if _visual_root != null:
			_visual_root.rotation.x = 0.0
	else:
		_lake_drift_vel = Vector2(randf_range(-1.35, 1.35), randf_range(1.6, 2.8))

func sink_and_free() -> void:
	in_lake = false
	if _collider_shape != null:
		_collider_shape.disabled = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:y", global_position.y - 0.65, 0.55).set_ease(Tween.EASE_IN)
	if is_instance_valid(_visual_root):
		tw.tween_property(_visual_root, "scale", Vector3.ONE * 0.05, 0.55)
	tw.chain().tween_callback(queue_free)

func _disable_shadows_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows_recursive(child)

func take_hit(dmg: int, _attacker_pos: Vector3) -> void:
	if is_falling or hp <= 0:
		return
	hp = maxi(0, hp - dmg)
	var hit_progress := float(max_hp - hp) / float(maxi(1, max_hp))
	SoundManager.play("pick_hit", 0.96 + hit_progress * 0.38, -5.0)

	if _vfx != null:
		_vfx.spawn_ice_burst(global_position + Vector3(0.0, 0.35 * _base_scale, 0.0), 6 if is_giant else 4, 1.15 if is_giant else 0.85)

	_shake_time = 0.18
	var squash := _visual_root.create_tween()
	var base := Vector3.ONE * _base_scale
	squash.tween_property(_visual_root, "scale", Vector3(base.x * 1.12, base.y * 0.86, base.z * 1.12), 0.06)
	squash.tween_property(_visual_root, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_update_damage_stage()

	if hp <= 0:
		SoundManager.play("ice_break", 0.82 if is_giant else 1.05, -4.0)
		if _vfx != null:
			_vfx.spawn_ice_burst(global_position + Vector3(0.0, 0.4 * _base_scale, 0.0), 14 if is_giant else 9, 1.45 if is_giant else 1.0)
		broken.emit(self, is_giant, global_position)
		queue_free()

func _update_damage_stage() -> void:
	var ratio := float(max_hp - hp) / float(maxi(1, max_hp))
	var crack_val := 0.0
	if hp >= max_hp:
		damage_stage = 0
		crack_val = 0.0
	elif ratio < 0.45:
		damage_stage = 1
		crack_val = 0.34
	elif ratio < 0.72:
		damage_stage = 2
		crack_val = 0.68
	else:
		damage_stage = 3
		crack_val = 1.0

	if _ice_mat != null:
		_ice_mat.set_shader_parameter("crack_amount", crack_val)

func _outline_inner_tuna_only(root: Node) -> void:
	for child in root.get_children():
		if child.name.to_lower().contains("tuna"):
			OutlineHelper.apply(child, OutlineConfig.Category.FISH, true)
		else:
			_outline_inner_tuna_only(child)
