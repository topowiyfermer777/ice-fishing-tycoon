extends Node3D
class_name VfxManager

const ICE_CHUNKS_SCENE := preload("res://exports/glb/Food_And_Ice/IceChunks.glb")

var _chunk_meshes: Array[Mesh] = []
var _chunk_mat: StandardMaterial3D
var _sparkle_mesh: BoxMesh
var _sparkle_mat: StandardMaterial3D
var _puff_mesh: SphereMesh
var _splash_mesh: SphereMesh
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_extract_ice_chunk_meshes()

	_sparkle_mesh = BoxMesh.new()
	_sparkle_mesh.size = Vector3(0.09, 0.09, 0.09)
	_sparkle_mat = StandardMaterial3D.new()
	_sparkle_mat.albedo_color = Color(0.75, 0.95, 1.0, 1.0)
	_sparkle_mat.emission_enabled = true
	_sparkle_mat.emission = Color(0.55, 0.9, 1.0, 1.0)
	_sparkle_mat.emission_energy_multiplier = 2.0

	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.18
	_puff_mesh.height = 0.36
	_puff_mesh.radial_segments = 8
	_puff_mesh.rings = 4

	_splash_mesh = SphereMesh.new()
	_splash_mesh.radius = 0.08
	_splash_mesh.height = 0.16
	_splash_mesh.radial_segments = 6
	_splash_mesh.rings = 3

func _extract_ice_chunk_meshes() -> void:
	var inst := ICE_CHUNKS_SCENE.instantiate()
	_collect_meshes(inst)
	inst.queue_free()

	_chunk_mat = StandardMaterial3D.new()
	_chunk_mat.albedo_color = Color(0.78, 0.93, 1.0, 0.9)
	_chunk_mat.roughness = 0.15
	_chunk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _collect_meshes(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		_chunk_meshes.append((n as MeshInstance3D).mesh)
	for c in n.get_children():
		_collect_meshes(c)

func spawn_ice_burst(pos: Vector3, count: int = 7, power: float = 1.0) -> void:
	if _chunk_meshes.is_empty():
		return
	for i in range(count):
		var mi := MeshInstance3D.new()
		mi.mesh = _chunk_meshes[_rng.randi_range(0, _chunk_meshes.size() - 1)]
		mi.material_override = _chunk_mat
		mi.scale = Vector3.ONE * _rng.randf_range(0.55, 1.15) * power
		add_child(mi)
		mi.global_position = pos + Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.1, 0.5), _rng.randf_range(-0.2, 0.2))

		var vel := Vector3(
			_rng.randf_range(-2.2, 2.2) * power,
			_rng.randf_range(2.2, 4.4) * power,
			_rng.randf_range(-2.2, 2.2) * power
		)
		var rot_spd := Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		_animate_debris(mi, vel, rot_spd, 0.55)

func spawn_water_splash(pos: Vector3, count: int = 5, scale_mult: float = 1.0) -> void:
	for i in range(count):
		var mi := MeshInstance3D.new()
		mi.mesh = _splash_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.88, 0.96, 1.0, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.scale = Vector3.ONE * _rng.randf_range(0.6, 1.3) * scale_mult
		add_child(mi)
		mi.global_position = pos + Vector3(_rng.randf_range(-0.15, 0.15), 0.05, _rng.randf_range(-0.15, 0.15))

		var vel := Vector3(
			_rng.randf_range(-1.4, 1.4) * scale_mult,
			_rng.randf_range(1.6, 3.0) * scale_mult,
			_rng.randf_range(-1.4, 1.4) * scale_mult
		)
		_animate_debris(mi, vel, Vector3.ZERO, 0.42, mat)

func spawn_sparkle(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sparkle_mesh
	mi.material_override = _sparkle_mat
	add_child(mi)
	mi.global_position = pos + Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1))
	mi.rotation = Vector3(0.7, 0.7, 0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.28).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "position:y", mi.position.y + 0.25, 0.28)
	tw.chain().tween_callback(mi.queue_free)

func spawn_customer_puff(pos: Vector3) -> void:
	for i in range(9):
		var mi := MeshInstance3D.new()
		mi.mesh = _puff_mesh
		var mat := StandardMaterial3D.new()
		var is_green := (i % 2 == 0)
		mat.albedo_color = Color(0.45, 0.96, 0.45, 0.92) if is_green else Color(0.95, 1.0, 0.95, 0.92)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.7
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.scale = Vector3.ONE * _rng.randf_range(0.6, 1.15)
		add_child(mi)
		mi.global_position = pos + Vector3(_rng.randf_range(-0.22, 0.22), _rng.randf_range(0.25, 0.75), _rng.randf_range(-0.22, 0.22))
		var target := mi.global_position + Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(0.4, 1.0), _rng.randf_range(-0.45, 0.45))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", target, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 1.4, 0.2)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
		tw.chain().tween_callback(mi.queue_free)

func spawn_chop_sparks(pos: Vector3) -> void:
	for i in range(4):
		var mi := MeshInstance3D.new()
		mi.mesh = _sparkle_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.55, 0.45, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.35, 1.0)
		mat.emission_energy_multiplier = 1.5
		mi.material_override = mat
		mi.scale = Vector3.ONE * 0.65
		add_child(mi)
		mi.global_position = pos
		var vel := Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(1.2, 2.4), _rng.randf_range(-1.4, 1.4))
		_animate_debris(mi, vel, Vector3(6, 6, 6), 0.28)

func spawn_build_burst(pos: Vector3) -> void:
	spawn_water_splash(pos, 10, 1.5)
	for i in range(6):
		spawn_sparkle(pos + Vector3(_rng.randf_range(-0.6, 0.6), 0.3, _rng.randf_range(-0.6, 0.6)))

func _animate_debris(mi: MeshInstance3D, vel: Vector3, rot_spd: Vector3, life: float, fade_mat: StandardMaterial3D = null) -> void:
	var start := mi.global_position
	var wr: WeakRef = weakref(mi)
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var obj := wr.get_ref() as MeshInstance3D
		if obj == null:
			return
		var elapsed := t * life
		var p := start + vel * elapsed
		p.y -= 0.5 * 14.0 * elapsed * elapsed
		obj.global_position = p
		if rot_spd != Vector3.ZERO:
			obj.rotation += rot_spd * 0.016
		var s := maxf(0.01, 1.0 - maxf(0.0, t - 0.5) * 2.0)
		obj.scale = Vector3.ONE * s * 0.85
		if fade_mat != null:
			fade_mat.albedo_color.a = 1.0 - t
	, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
