extends Node3D
class_name StackCarry

const TUNA_V2_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_v2.glb")
const TUNA_STEAK_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_Steak.glb")
const CASH_BUNDLE_SCENE := preload("res://exports/glb/Stations_And_UI/Cash_Bundle.glb")
const CASH_STACK_5_SCENE := preload("res://exports/glb/Stations_And_UI/Cash_Stack_5.glb")

const MAX_RAW_CAPACITY := 8
const MAX_STEAK_CAPACITY := 24
const CASH_SCALE := 0.72
const SPRING_STIFFNESS := 48.0
const SPRING_DAMPING := 8.2

var hands_anchor: Node3D
var back_anchor: Node3D

# Each entry: { "type": GameState.ItemType, "node": Node3D, "base_pos": Vector3, "base_rot": Vector3 }
var _hand_items: Array[Dictionary] = []
# Each entry: { "node": Node3D, "base_y": float }
var _cash_nodes: Array[Dictionary] = []
var _stack5_pool: Array[Node3D] = []
var _bundle1_pool: Array[Node3D] = []

var _last_pos: Vector3 = Vector3.ZERO
var _last_vel: Vector3 = Vector3.ZERO
var _last_yaw: float = 0.0
var _sway_pos := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _last_money_shown: int = -1

func _ready() -> void:
	hands_anchor = Node3D.new()
	hands_anchor.name = "HandsStack"
	hands_anchor.position = Vector3(0.0, 0.46, 0.30)
	add_child(hands_anchor)

	back_anchor = Node3D.new()
	back_anchor.name = "BackCashStack"
	back_anchor.position = Vector3(0.0, 0.34, -0.24)
	add_child(back_anchor)
	_init_cash_pool()

	_last_pos = global_position
	_last_yaw = global_rotation.y
	GameState.money_changed.connect(_on_money_changed)
	GameState.game_reset.connect(clear_all)
	_on_money_changed(GameState.money)

func _process(delta: float) -> void:
	var dt := clampf(delta, 0.001, 0.05)
	var vel := (global_position - _last_pos) / dt
	var accel := (vel - _last_vel) / dt
	_last_pos = global_position
	_last_vel = vel

	var cur_yaw := global_rotation.y
	var ang_vel := angle_difference(_last_yaw, cur_yaw) / dt
	_last_yaw = cur_yaw

	var inv_basis := global_basis.inverse()
	var local_vel := inv_basis * vel
	var local_acc := inv_basis * accel

	# Multi-directional inertia target: leans back on forward run, tilts sideways on strafes & turns
	var target_x := clampf(-local_vel.x * 0.14 - local_acc.x * 0.025 + ang_vel * 0.11, -1.35, 1.35)
	var target_z := clampf(-local_vel.z * 0.16 - local_acc.z * 0.025, -1.35, 1.35)
	var target := Vector2(target_x, target_z)

	var force := (target - _sway_pos) * SPRING_STIFFNESS - _sway_vel * SPRING_DAMPING
	_sway_vel += force * dt
	_sway_pos += _sway_vel * dt

	# Apply curved multi-axis bend to hands stack (index 0 stays fixed in hands)
	for i in range(_hand_items.size()):
		var entry: Dictionary = _hand_items[i]
		var n: Node3D = entry["node"]
		if not is_instance_valid(n):
			continue
		var base_pos: Vector3 = entry["base_pos"]
		var base_rot: Vector3 = entry["base_rot"]
		if i == 0:
			n.position = base_pos
			n.rotation = base_rot
			continue

		var bend := minf(1.25, pow(float(i), 1.32) * 0.020)
		var dx := _sway_pos.x * bend
		var dz := _sway_pos.y * bend
		var drop_y := -_sway_pos.length() * bend * 0.12
		n.position = Vector3(base_pos.x + dx, base_pos.y + drop_y, base_pos.z + dz)

		var tilt_x := _sway_pos.y * minf(0.45, float(i) * 0.032)
		var tilt_z := -_sway_pos.x * minf(0.45, float(i) * 0.032)
		n.rotation = Vector3(base_rot.x + tilt_x, base_rot.y, base_rot.z + tilt_z)

	# Apply identical multi-directional bend to back cash stack (oriented parallel to back via Y = PI/2)
	for i in range(_cash_nodes.size()):
		var centry: Dictionary = _cash_nodes[i]
		var cn: Node3D = centry["node"]
		if not is_instance_valid(cn):
			continue
		var by: float = centry["base_y"]
		if i == 0:
			cn.position = Vector3(0.0, by, 0.0)
			cn.rotation = Vector3(0.0, PI * 0.5, 0.0)
			continue
		var cbend := minf(1.1, pow(float(i), 1.35) * 0.024)
		var tilt := minf(0.4, float(i) * 0.035)
		cn.position = Vector3(_sway_pos.x * cbend, by - _sway_pos.length() * cbend * 0.1, _sway_pos.y * cbend)
		cn.rotation = Vector3(-_sway_pos.x * tilt, PI * 0.5, _sway_pos.y * tilt)

func is_empty() -> bool:
	return _hand_items.is_empty()

func get_hand_count() -> int:
	return _hand_items.size()

func is_holding_raw() -> bool:
	if _hand_items.is_empty():
		return false
	var t: int = _hand_items[0]["type"]
	return t == GameState.ItemType.RAW_TUNA or t == GameState.ItemType.GIANT_TUNA

func is_holding_steaks() -> bool:
	return not _hand_items.is_empty() and _hand_items[0]["type"] == GameState.ItemType.TUNA_STEAK

func can_accept(item_type: int) -> bool:
	if item_type == GameState.ItemType.TUNA_STEAK:
		return _hand_items.is_empty() or (is_holding_steaks() and _hand_items.size() < MAX_STEAK_CAPACITY)
	else:
		if _hand_items.is_empty():
			return true
		return is_holding_raw() and _hand_items.size() < MAX_RAW_CAPACITY

func push_item(item_type: int) -> Node3D:
	if not can_accept(item_type):
		return null
	var inst: Node3D
	var idx := _hand_items.size()
	var base_pos := Vector3.ZERO
	var base_rot := Vector3.ZERO
	var target_scale := Vector3.ONE

	if item_type == GameState.ItemType.TUNA_STEAK:
		inst = TUNA_STEAK_SCENE.instantiate() as Node3D
		OutlineHelper.apply(inst, OutlineConfig.Category.STEAK, true)
		hands_anchor.add_child(inst)
		base_pos = Vector3(0.0, float(idx) * 0.062, 0.0)
		base_rot = Vector3(0.0, randf_range(-0.08, 0.08), 0.0)
		target_scale = Vector3.ONE
	else:
		inst = TUNA_V2_SCENE.instantiate() as Node3D
		OutlineHelper.apply(inst, OutlineConfig.Category.FISH, true)
		hands_anchor.add_child(inst)
		var scl := 1.45 if item_type == GameState.ItemType.GIANT_TUNA else 0.92
		target_scale = Vector3.ONE * scl
		base_rot = Vector3(0.0, PI * 0.5, PI * 0.5)
		var y_off := _compute_raw_y_offset(idx, item_type == GameState.ItemType.GIANT_TUNA)
		# Pull fish inward along -Z to compensate for Tuna_v2's Y center (+0.223) so it sits snugly in hands
		base_pos = Vector3(0.036 * scl, y_off + 0.04, -0.22 * scl)

	inst.position = base_pos
	inst.rotation = base_rot
	_hand_items.append({
		"type": item_type,
		"node": inst,
		"base_pos": base_pos,
		"base_rot": base_rot,
	})
	inst.scale = target_scale * 0.01
	inst.create_tween().tween_property(inst, "scale", target_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return inst

func pop_item() -> int:
	if _hand_items.is_empty():
		return -1
	var entry: Dictionary = _hand_items.pop_back()
	var n: Node3D = entry["node"]
	if is_instance_valid(n):
		n.queue_free()
	return int(entry["type"])

func get_top_hand_world_pos() -> Vector3:
	if _hand_items.is_empty():
		return hands_anchor.global_position
	var n: Node3D = _hand_items[-1]["node"]
	return n.global_position if is_instance_valid(n) else hands_anchor.global_position

func get_cash_top_world_pos() -> Vector3:
	if _cash_nodes.is_empty():
		return back_anchor.global_position
	var n: Node3D = _cash_nodes[-1]["node"]
	return n.global_position if is_instance_valid(n) else back_anchor.global_position

func clear_all() -> void:
	for entry in _hand_items:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_hand_items.clear()
	_last_money_shown = 0
	_rebuild_cash_tower(0)

func _compute_raw_y_offset(idx: int, is_giant: bool) -> float:
	var y := 0.0
	for i in range(idx):
		y += 0.28 if _hand_items[i]["type"] == GameState.ItemType.GIANT_TUNA else 0.17
	if is_giant:
		y += 0.08
	return y

func _on_money_changed(new_amount: int) -> void:
	var bundles := mini(160, int(ceil(float(new_amount) / 10.0)))
	if bundles == _last_money_shown:
		return
	_last_money_shown = bundles
	_rebuild_cash_tower(bundles)

func _init_cash_pool() -> void:
	for i in range(32):
		var s5 := CASH_STACK_5_SCENE.instantiate() as Node3D
		OutlineHelper.apply(s5, OutlineConfig.Category.CASH, true)
		s5.scale = Vector3.ONE * CASH_SCALE
		s5.rotation = Vector3(0.0, PI * 0.5, 0.0)
		s5.visible = false
		back_anchor.add_child(s5)
		_stack5_pool.append(s5)
	for i in range(4):
		var b1 := CASH_BUNDLE_SCENE.instantiate() as Node3D
		OutlineHelper.apply(b1, OutlineConfig.Category.CASH, true)
		b1.scale = Vector3.ONE * CASH_SCALE
		b1.rotation = Vector3(0.0, PI * 0.5, 0.0)
		b1.visible = false
		back_anchor.add_child(b1)
		_bundle1_pool.append(b1)

func _rebuild_cash_tower(bundles: int) -> void:
	for s5 in _stack5_pool:
		if is_instance_valid(s5):
			s5.visible = false
	for b1 in _bundle1_pool:
		if is_instance_valid(b1):
			b1.visible = false
	_cash_nodes.clear()

	if bundles <= 0 or back_anchor == null:
		return

	var y := 0.0
	var fives := mini(_stack5_pool.size(), int(bundles / 5))
	var ones := mini(_bundle1_pool.size(), bundles % 5)
	for i in range(fives):
		var node := _stack5_pool[i]
		node.visible = true
		node.position = Vector3(0.0, y, 0.0)
		node.rotation = Vector3(0.0, PI * 0.5, 0.0)
		_cash_nodes.append({ "node": node, "base_y": y })
		y += 0.42
	for i in range(ones):
		var node := _bundle1_pool[i]
		node.visible = true
		node.position = Vector3(0.0, y, 0.0)
		node.rotation = Vector3(0.0, PI * 0.5, 0.0)
		_cash_nodes.append({ "node": node, "base_y": y })
		y += 0.088
