extends Node3D
class_name ChefStation

const CHEF_SCENE := preload("res://exports/glb/Characters/Chef.glb")
const CLEAVER_SCENE := preload("res://exports/glb/Tools/Chef_Cleaver.glb")
const CHEF_TABLE_SCENE := preload("res://exports/glb/Stations_And_UI/ChefTable.glb")
const TUNA_V2_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_v2.glb")
const TUNA_SPLIT_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_v2_Split.glb")
const TUNA_STEAK_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_Steak.glb")

const CHOP_PART_NAMES := [
	"Tuna_Part_05_Tail",
	"Tuna_Part_04_Rear",
	"Tuna_Part_03_Mid",
	"Tuna_Part_02_Front",
	"Tuna_Part_01_Head",
]

# Measured directly from Chef.glb "Chop" clip (0.800s cycle: apex at 0.30s, board impact at 0.50s)
const CHOP_IMPACT_TIME := 0.50

@export var normal_chop_speed: float = 2.4
@export var giant_chop_speed: float = 3.4
@export var steaks_per_giant_segment: int = 3

var _chef_rig: CharacterRig
var _table_node: Node3D
var _board_point: Marker3D
var _vfx: VfxManager
var _conveyor_system: Node
var _camp: CampBuilder

var _shore_fish: Array[Dictionary] = []
var _input_fish: Array[Dictionary] = []
var _output_steaks: Array[Node3D] = []

var _active_split_node: Node3D
var _active_is_giant: bool = false
var _active_part_idx: int = 0
var _is_chopping: bool = false
var _awaiting_finish: bool = false
var _prev_anim_pos: float = 0.0

func setup(vfx: VfxManager, conveyor: Node = null, camp: CampBuilder = null) -> void:
	_vfx = vfx
	_conveyor_system = conveyor
	_camp = camp

func _ready() -> void:
	_init_table_and_chef()
	GameState.game_reset.connect(reset)

func _init_table_and_chef() -> void:
	_table_node = get_node_or_null("ChefTable") as Node3D
	if _table_node == null:
		_table_node = CHEF_TABLE_SCENE.instantiate() as Node3D
		_table_node.name = "ChefTable"
		_table_node.rotation.y = PI * 0.5
		_table_node.scale = Vector3(1.18, 1.05, 1.18)
		add_child(_table_node)
	_hide_static_table_props(_table_node)
	OutlineHelper.apply(_table_node, OutlineConfig.Category.STATION, true)

	_board_point = get_node_or_null("BoardFishPoint") as Marker3D

	_chef_rig = get_node_or_null("ChefRig") as CharacterRig
	if _chef_rig == null:
		_chef_rig = CharacterRig.new()
		_chef_rig.name = "ChefRig"
		_chef_rig.position = Vector3(-0.72, 0.0, 0.0)
		_chef_rig.rotation.y = PI * 0.5
		add_child(_chef_rig)
	_chef_rig.setup_existing_or_spawn(CHEF_SCENE, OutlineConfig.Category.CHARACTER)
	_chef_rig.attach_tool(
		"hand.R",
		CLEAVER_SCENE,
		Vector3(0.00806, 0.05472, -0.01114),
		Quaternion(0.04387, 0.13219, 0.73359, 0.66517),
		Vector3(0.88, 0.88, 0.88)
	)
	_chef_rig.play_anim("Idle", 0.1, 1.0)

func _hide_static_table_props(node: Node) -> void:
	for c in node.get_children():
		if c.name == "ChefTable_Steak" or c.name == "ChefTable_Knife" or c.name == "ChefTable_Knife_Handle":
			c.visible = false
		else:
			_hide_static_table_props(c)

func reset() -> void:
	for e in _shore_fish:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_shore_fish.clear()

	for e in _input_fish:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_input_fish.clear()

	for s in _output_steaks:
		if is_instance_valid(s):
			s.queue_free()
	_output_steaks.clear()

	if is_instance_valid(_active_split_node):
		_active_split_node.queue_free()
	_active_split_node = null
	_is_chopping = false
	_awaiting_finish = false
	_active_part_idx = 0
	_prev_anim_pos = 0.0
	if _chef_rig != null:
		_chef_rig.play_anim("Idle", 0.1, 1.0)

func _shore_base() -> Vector3:
	return _camp.get_raw_fish_pad_pos() if _camp != null else GameState.RAW_FISH_PAD_POS

func _input_base() -> Vector3:
	return _camp.get_chef_input_pad_pos() if _camp != null else GameState.CHEF_INPUT_PAD_POS

func _output_base() -> Vector3:
	return _camp.get_chef_output_pad_pos() if _camp != null else GameState.CHEF_OUTPUT_PAD_POS

func get_next_shore_slot_pos() -> Vector3:
	var idx := _shore_fish.size()
	var col := idx % 2
	var row := int(idx / 2) % 3
	var layer := int(idx / 6)
	return _shore_base() + Vector3((col - 0.5) * 0.34, 0.1 + layer * 0.16, (row - 1) * 0.28)

func add_shore_fish(fish_type: int) -> void:
	var fish := TUNA_V2_SCENE.instantiate() as Node3D
	OutlineHelper.apply(fish, OutlineConfig.Category.FISH, true)
	var scl := 1.45 if fish_type == GameState.ItemType.GIANT_TUNA else 0.92
	fish.scale = Vector3.ONE * scl
	fish.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(fish)
	fish.global_position = get_next_shore_slot_pos()
	_shore_fish.append({ "type": fish_type, "node": fish })

	var target := fish.scale
	fish.scale = target * 0.2
	fish.create_tween().tween_property(fish, "scale", target, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func pop_shore_fish() -> int:
	if _shore_fish.is_empty():
		return -1
	var entry: Dictionary = _shore_fish.pop_back()
	if is_instance_valid(entry["node"]):
		entry["node"].queue_free()
	return int(entry["type"])

func has_shore_fish() -> bool:
	return not _shore_fish.is_empty()

func receive_raw_fish(fish_type: int, from_pos: Vector3 = Vector3.ZERO) -> void:
	var fish := TUNA_V2_SCENE.instantiate() as Node3D
	OutlineHelper.apply(fish, OutlineConfig.Category.FISH, true)
	var scl := 1.45 if fish_type == GameState.ItemType.GIANT_TUNA else 0.92
	fish.scale = Vector3.ONE * scl
	fish.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(fish)
	var idx := _input_fish.size()
	var target_pos := _input_base() + Vector3(0.0, 0.1 + float(idx) * 0.16, 0.0)
	_input_fish.append({ "type": fish_type, "node": fish })

	if from_pos != Vector3.ZERO:
		ParabolaFlight.launch(self, fish, from_pos, target_pos, 0.22, 0.65)
	else:
		fish.global_position = target_pos

func pop_ready_steak() -> bool:
	if _output_steaks.is_empty():
		return false
	var s: Node3D = _output_steaks.pop_back()
	if is_instance_valid(s):
		s.queue_free()
	return true

func has_ready_steak() -> bool:
	return not _output_steaks.is_empty()

func _process(_delta: float) -> void:
	if not _is_chopping:
		if not _input_fish.is_empty():
			_start_next_fish()
		return

	if _chef_rig == null or _chef_rig.anim_player == null:
		return

	var cur_pos := _chef_rig.anim_player.current_animation_position
	var wrapped := cur_pos < _prev_anim_pos

	if _awaiting_finish:
		if wrapped:
			if is_instance_valid(_active_split_node):
				_active_split_node.queue_free()
			_active_split_node = null
			_is_chopping = false
			_awaiting_finish = false
			if not _input_fish.is_empty():
				_start_next_fish()
			else:
				_chef_rig.play_anim("Idle", 0.12, 1.0)
	else:
		var crossed := (not wrapped and _prev_anim_pos < CHOP_IMPACT_TIME and cur_pos >= CHOP_IMPACT_TIME) \
			or (wrapped and (_prev_anim_pos < CHOP_IMPACT_TIME or cur_pos >= CHOP_IMPACT_TIME))
		if crossed:
			_perform_chop_step()

	_prev_anim_pos = cur_pos

func _start_next_fish() -> void:
	var entry: Dictionary = _input_fish.pop_back()
	if is_instance_valid(entry["node"]):
		entry["node"].queue_free()

	_active_is_giant = (int(entry["type"]) == GameState.ItemType.GIANT_TUNA)
	_active_part_idx = 0
	_is_chopping = true
	_awaiting_finish = false
	_prev_anim_pos = 0.0

	_active_split_node = TUNA_SPLIT_SCENE.instantiate() as Node3D
	OutlineHelper.apply(_active_split_node, OutlineConfig.Category.FISH, true)
	var scl := 1.55 if _active_is_giant else 0.98
	_active_split_node.scale = Vector3.ONE * scl
	_active_split_node.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(_active_split_node)
	var board_pos := _board_point.global_position if _board_point != null else (global_position + Vector3(0.0, 0.47, 0.0))
	_active_split_node.global_position = board_pos + Vector3(0.18 * scl, 0.0, 0.0)

	_chef_rig.play_anim("Chop", 0.06, giant_chop_speed if _active_is_giant else normal_chop_speed, true)

func _perform_chop_step() -> void:
	if _active_part_idx < CHOP_PART_NAMES.size():
		var part_name: String = CHOP_PART_NAMES[_active_part_idx]
		var part := _find_node_by_name(_active_split_node, part_name)
		if part != null:
			part.visible = false
		SoundManager.play("chop", 1.15 if _active_is_giant else 1.0, -5.0)
		if _vfx != null:
			var spark_pos := _board_point.global_position if _board_point != null else (global_position + Vector3(0.0, 0.55, 0.0))
			_vfx.spawn_chop_sparks(spark_pos + Vector3(0.0, 0.08, 0.0))

		if _active_is_giant:
			for k in range(steaks_per_giant_segment):
				_emit_steak(float(k) * 0.04)
		else:
			if _active_part_idx in [1, 3, 4]:
				_emit_steak(0.0)

		_active_part_idx += 1
		if _active_part_idx >= CHOP_PART_NAMES.size():
			_awaiting_finish = true

func _emit_steak(delay: float) -> void:
	var start := global_position + Vector3(0.0, 0.52, -0.25)
	if GameState.conveyor_built and _conveyor_system != null and _conveyor_system.has_method("enqueue_output_steak"):
		var tw := create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			_conveyor_system.enqueue_output_steak(start)
		)
		return

	var steak := TUNA_STEAK_SCENE.instantiate() as Node3D
	OutlineHelper.apply(steak, OutlineConfig.Category.STEAK, true)
	add_child(steak)
	var idx := _output_steaks.size()
	var col := idx % 2
	var layer := int(idx / 2)
	var dest := _output_base() + Vector3((col - 0.5) * 0.36, 0.02 + float(layer) * 0.06, 0.0)
	_output_steaks.append(steak)

	steak.visible = false
	var steak_wr: WeakRef = weakref(steak)
	var tw := steak.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		var s := steak_wr.get_ref() as Node3D
		if s == null:
			return
		s.visible = true
		ParabolaFlight.launch(self, s, start, dest, 0.24, 0.55)
	)

func _find_node_by_name(root: Node, target_name: String) -> Node3D:
	if root == null:
		return null
	if root.name == target_name and root is Node3D:
		return root as Node3D
	for c in root.get_children():
		var found := _find_node_by_name(c, target_name)
		if found != null:
			return found
	return null
