extends CharacterBody3D
class_name WorkerAI

const KENNY_SCENE := preload("res://exports/glb/Characters/Worker_Kenny.glb")
const PICKAXE_SCENE := preload("res://exports/glb/Tools/Ice_Pickaxe.glb")

@export var move_speed: float = 4.4
@export var mine_interval: float = 0.60

var rig: CharacterRig
var _river_ice: RiverIceSystem
var _vfx: VfxManager
var _target_block: IceBlock
var _attack_offset := Vector3.ZERO
var _mine_timer: float = 0.0
var _splash_timer: float = 0.0
var _dual_swing: bool = false
var _worker_idx: int = 0

func setup(worker_idx: int, river_ice: RiverIceSystem, vfx: VfxManager) -> void:
	_worker_idx = worker_idx
	_river_ice = river_ice
	_vfx = vfx
	var angle := float(worker_idx) * 1.45 + 0.6
	_attack_offset = Vector3(cos(angle), 0.0, sin(angle))

func _ready() -> void:
	rig = get_node_or_null("KennyRig") as CharacterRig
	if rig == null:
		rig = CharacterRig.new()
		rig.name = "KennyRig"
		add_child(rig)
	rig.setup_existing_or_spawn(KENNY_SCENE, OutlineConfig.Category.CHARACTER)
	rig.attach_tool("hand.R", PICKAXE_SCENE, Vector3(0.0, 0.08908, 0.0), Quaternion(0.5, -0.5, -0.5, 0.5), Vector3.ONE)
	rig.attach_tool("hand.L", PICKAXE_SCENE, Vector3(0.0, 0.08908, 0.0), Quaternion(0.5, -0.5, -0.5, 0.5), Vector3.ONE)
	rig.set_tools_visible(true)
	rig.play_anim("Run", 0.08, 1.2)

func _exit_tree() -> void:
	_release_target()

func _release_target() -> void:
	if is_instance_valid(_target_block):
		_target_block.reserved_workers = maxi(0, _target_block.reserved_workers - 1)
	_target_block = null

func _physics_process(delta: float) -> void:
	_mine_timer = maxf(0.0, _mine_timer - delta)

	if not is_instance_valid(_target_block) or _target_block.is_falling or _target_block.in_lake or _target_block.hp <= 0:
		_release_target()
		if _river_ice != null:
			var next := _river_ice.find_worker_target(global_position, null)
			if next != null:
				_target_block = next
				_target_block.reserved_workers += 1

	var target_y := (GameState.WATER_Y + 0.03) if global_position.x < 0.0 else GameState.CAMP_Y

	if not is_instance_valid(_target_block):
		var patrol := Vector3(-1.4 - float(_worker_idx % 2) * 1.1, GameState.WATER_Y + 0.03, 1.5 - float(_worker_idx) * 0.8)
		_move_towards(patrol, delta)
		if global_position.distance_to(patrol) < 0.2:
			rig.play_anim("Idle", 0.12, 1.0)
		else:
			rig.play_anim("Run", 0.1, 1.15)
		return

	var stand_dist := _target_block.radius + 0.68
	var desired := _target_block.global_position + _attack_offset * stand_dist
	desired.x = clampf(desired.x, -3.45, -0.25)
	desired.z = clampf(desired.z, -6.2, 3.78)
	desired.y = target_y

	var dist_to_block := Vector2(global_position.x - _target_block.global_position.x, global_position.z - _target_block.global_position.z).length()
	if dist_to_block > _target_block.radius + 0.95:
		_move_towards(desired, delta)
		rig.play_anim("Run", 0.1, 1.2)
	else:
		velocity = Vector3.ZERO
		var look_vec := _target_block.global_position - global_position
		look_vec.y = 0.0
		if look_vec.length_squared() > 0.001:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(look_vec.x, look_vec.z), minf(1.0, delta * 14.0))

		if _mine_timer <= 0.0:
			_mine_timer = mine_interval
			_dual_swing = not _dual_swing
			rig.play_anim("Mine_Dual_Strike" if _dual_swing else "Mine_Strike", 0.06, 1.25, true)
			var block_wr: WeakRef = weakref(_target_block)
			get_tree().create_timer(0.16).timeout.connect(func() -> void:
				if not can_process():
					return
				var b := block_wr.get_ref() as Node3D
				if b != null and b.has_method("take_hit"):
					b.take_hit(1, global_position)
			)

func _move_towards(dest: Vector3, delta: float) -> void:
	var diff := dest - global_position
	diff.y = 0.0
	if diff.length() > 0.05:
		var dir := diff.normalized()
		global_position += dir * move_speed * delta
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
		if global_position.x < 0.0:
			_splash_timer += delta
			if _splash_timer >= 0.14:
				_splash_timer = 0.0
				if _vfx != null:
					_vfx.spawn_water_splash(Vector3(global_position.x, GameState.WATER_Y + 0.04, global_position.z), 2, 0.7)
	var ty := (GameState.WATER_Y + 0.03) if global_position.x < 0.0 else GameState.CAMP_Y
	global_position.y = lerpf(global_position.y, ty, minf(1.0, delta * 12.0))
