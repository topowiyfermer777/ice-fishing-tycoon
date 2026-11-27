extends Node3D
class_name RiverBuilder

@onready var river_surface: MeshInstance3D = get_node_or_null("RiverSurface") as MeshInstance3D
@onready var dam_container: Node3D = get_node_or_null("LogDamContainer") as Node3D

@onready var _spawn_start: Marker3D = get_node_or_null("Markers/SpawnLineStart") as Marker3D
@onready var _spawn_end: Marker3D = get_node_or_null("Markers/SpawnLineEnd") as Marker3D
@onready var _dam_start: Marker3D = get_node_or_null("Markers/DamLineStart") as Marker3D
@onready var _cliff_marker: Marker3D = get_node_or_null("Markers/CliffEdgeMarker") as Marker3D

var _water_mat: ShaderMaterial
var _dam_logs: Array[Dictionary] = []
var _vfx: VfxManager

func setup(vfx: VfxManager) -> void:
	_vfx = vfx

func _ready() -> void:
	if river_surface != null and river_surface.material_override is ShaderMaterial:
		_water_mat = (river_surface.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		river_surface.material_override = _water_mat
		_water_mat.set_shader_parameter("dam_z", get_dam_z())
		_water_mat.set_shader_parameter("dam_built", 0.0)
		_water_mat.set_shader_parameter("cliff_z", get_cliff_z())

	if dam_container != null:
		for c in dam_container.get_children():
			if c is Node3D:
				var ln := c as Node3D
				OutlineHelper.apply(ln, OutlineConfig.Category.FENCE, true)
				_dam_logs.append({
					"node": ln,
					"pos": ln.position,
					"scale": ln.scale,
				})
		dam_container.visible = false

	_setup_waterfall_particles()
	GameState.dam_built_signal.connect(_on_dam_built)
	GameState.game_reset.connect(_on_game_reset)

func _setup_waterfall_particles() -> void:
	var x_range := get_spawn_x_range()
	var center_x := (x_range.x + x_range.y) * 0.5
	var cz := get_cliff_z()
	var lake_y := GameState.LAKE_Y

	# Rising misty foam puffs along the waterfall plunge line
	var mist := GPUParticles3D.new()
	mist.name = "WaterfallMist"
	mist.amount = 34
	mist.lifetime = 1.15
	mist.preprocess = 1.0
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.position = Vector3(center_x, lake_y + 0.08, cz + 0.48)

	var mist_pm := ParticleProcessMaterial.new()
	mist_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mist_pm.emission_box_extents = Vector3(1.85, 0.08, 0.18)
	mist_pm.direction = Vector3(0.0, 1.0, 0.35)
	mist_pm.spread = 32.0
	mist_pm.initial_velocity_min = 0.55
	mist_pm.initial_velocity_max = 1.15
	mist_pm.gravity = Vector3(0.0, 0.25, 0.0)
	mist_pm.scale_min = 0.85
	mist_pm.scale_max = 1.75

	var mist_grad := Gradient.new()
	mist_grad.colors = PackedColorArray([Color(0.95, 0.99, 1.0, 0.0), Color(0.95, 0.99, 1.0, 0.72), Color(0.95, 0.99, 1.0, 0.0)])
	mist_grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	var mist_ramp := GradientTexture1D.new()
	mist_ramp.gradient = mist_grad
	mist_pm.color_ramp = mist_ramp
	mist.process_material = mist_pm

	var mist_mesh := SphereMesh.new()
	mist_mesh.radius = 0.16
	mist_mesh.height = 0.32
	mist_mesh.radial_segments = 8
	mist_mesh.rings = 4
	var mist_mat := StandardMaterial3D.new()
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.vertex_color_use_as_albedo = true
	mist_mesh.material = mist_mat
	mist.draw_pass_1 = mist_mesh
	add_child(mist)

	# Crisp falling water spray droplets
	var spray := GPUParticles3D.new()
	spray.name = "WaterfallSpray"
	spray.amount = 42
	spray.lifetime = 0.65
	spray.preprocess = 0.6
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.position = Vector3(center_x, lake_y + 0.05, cz + 0.50)

	var spray_pm := ParticleProcessMaterial.new()
	spray_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spray_pm.emission_box_extents = Vector3(1.85, 0.06, 0.12)
	spray_pm.direction = Vector3(0.0, 1.0, 0.55)
	spray_pm.spread = 40.0
	spray_pm.initial_velocity_min = 1.6
	spray_pm.initial_velocity_max = 2.8
	spray_pm.gravity = Vector3(0.0, -7.5, 0.0)
	spray_pm.scale_min = 0.6
	spray_pm.scale_max = 1.25

	var spray_grad := Gradient.new()
	spray_grad.colors = PackedColorArray([Color(0.86, 0.96, 1.0, 0.95), Color(0.94, 0.99, 1.0, 0.0)])
	spray_grad.offsets = PackedFloat32Array([0.0, 1.0])
	var spray_ramp := GradientTexture1D.new()
	spray_ramp.gradient = spray_grad
	spray_pm.color_ramp = spray_ramp
	spray.process_material = spray_pm

	var spray_mesh := SphereMesh.new()
	spray_mesh.radius = 0.06
	spray_mesh.height = 0.12
	spray_mesh.radial_segments = 6
	spray_mesh.rings = 3
	var spray_mat := StandardMaterial3D.new()
	spray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spray_mat.vertex_color_use_as_albedo = true
	spray_mesh.material = spray_mat
	spray.draw_pass_1 = spray_mesh
	add_child(spray)

func get_spawn_x_range() -> Vector2:
	if _spawn_start != null and _spawn_end != null:
		var a := _spawn_start.global_position.x
		var b := _spawn_end.global_position.x
		return Vector2(minf(a, b), maxf(a, b))
	return Vector2(-2.95, -0.85)

func get_spawn_z() -> float:
	if _spawn_start != null:
		return _spawn_start.global_position.z
	return -13.2

func get_dam_z() -> float:
	if _dam_start != null:
		return _dam_start.global_position.z
	return GameState.DAM_Z

func get_cliff_z() -> float:
	if _cliff_marker != null:
		return _cliff_marker.global_position.z
	return GameState.CLIFF_Z

func get_water_y() -> float:
	if river_surface != null:
		return river_surface.global_position.y
	return GameState.WATER_Y

func _on_dam_built() -> void:
	if _water_mat != null:
		_water_mat.set_shader_parameter("dam_built", 1.0)
	if dam_container == null:
		return
	dam_container.visible = true

	for idx in range(_dam_logs.size()):
		var entry: Dictionary = _dam_logs[idx]
		var log_node: Node3D = entry["node"]
		if not is_instance_valid(log_node):
			continue
		var target_pos: Vector3 = entry["pos"]
		log_node.position = target_pos + Vector3(0.0, -1.1, 0.0)
		log_node.scale = entry["scale"]

		var delay := float(idx) * 0.035
		var log_wr: WeakRef = weakref(log_node)
		var tw := log_node.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(log_node, "position", target_pos, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _vfx != null:
			tw.tween_callback(func() -> void:
				var ln := log_wr.get_ref() as Node3D
				if ln != null:
					_vfx.spawn_water_splash(Vector3(ln.global_position.x, get_water_y() + 0.05, ln.global_position.z), 3, 1.0)
			)

func _on_game_reset() -> void:
	if _water_mat != null:
		_water_mat.set_shader_parameter("dam_built", 0.0)
	if dam_container != null:
		dam_container.visible = false
		for entry in _dam_logs:
			var log_node: Node3D = entry["node"]
			if is_instance_valid(log_node):
				log_node.position = entry["pos"]
				log_node.scale = entry["scale"]
