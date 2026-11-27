extends CharacterBody3D
class_name PlayerController

const HERO_SCENE := preload("res://exports/glb/Characters/Hero.glb")
const PICKAXE_SCENE := preload("res://exports/glb/Tools/Ice_Pickaxe.glb")

@export var move_speed: float = 4.15
@export var carry_speed: float = 3.85
@export var mine_range: float = 1.6
@export var mine_interval: float = 0.56
@export var mine_damage: int = 1

var rig: CharacterRig
var stack_carry: StackCarry

var _virtual_joy := Vector2.ZERO
var _river_ice_system: Node
var _chef_station: ChefStation
var _customer_system: Node
var _cash_zone: Node
var _camp_builder: CampBuilder
var _vfx: VfxManager

var _mine_timer: float = 0.0
var _dual_swing: bool = false
var _splash_timer: float = 0.0
var _unload_timer: float = 0.0
var _serve_timer: float = 0.0
var _pickup_timer: float = 0.0
var _in_drop_anim: bool = false
var _drop_anim_timer: float = 0.0
var input_enabled: bool = true

# --- Temporary First-Person Mode ---
var first_person_controls: bool = false
var _fp_yaw: float = 0.0
var _fp_attack_held: bool = false
var _fp_attack_queued: bool = false

func set_first_person_controls(enabled: bool) -> void:
	first_person_controls = enabled
	_fp_attack_held = false
	_fp_attack_queued = false
	if enabled and rig != null:
		_fp_yaw = rig.rotation.y

func set_first_person_input(yaw: float, attack_held: bool, attack_queued: bool) -> void:
	_fp_yaw = yaw
	_fp_attack_held = attack_held
	if attack_queued:
		_fp_attack_queued = true
# -----------------------------------

func setup(
	river_ice: Node,
	chef: ChefStation,
	customers: Node,
	cash_zone: Node,
	camp: CampBuilder,
	vfx: VfxManager
) -> void:
	_river_ice_system = river_ice
	_chef_station = chef
	_customer_system = customers
	_cash_zone = cash_zone
	_camp_builder = camp
	_vfx = vfx

func set_virtual_joystick(vec: Vector2) -> void:
	_virtual_joy = vec

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	rig = get_node_or_null("HeroRig") as CharacterRig
	if rig == null:
		rig = CharacterRig.new()
		rig.name = "HeroRig"
		add_child(rig)
	rig.setup_existing_or_spawn(HERO_SCENE, OutlineConfig.Category.CHARACTER)
	rig.attach_tool("hand.R", PICKAXE_SCENE, Vector3(0.0, 0.08908, 0.0), Quaternion(0.5, -0.5, -0.5, 0.5), Vector3.ONE)
	rig.attach_tool("hand.L", PICKAXE_SCENE, Vector3(0.0, 0.08908, 0.0), Quaternion(0.5, -0.5, -0.5, 0.5), Vector3.ONE)
	rig.set_tools_visible(false)

	stack_carry = rig.get_node_or_null("StackCarry") as StackCarry
	if stack_carry == null:
		var sibling := get_node_or_null("StackCarry") as StackCarry
		if sibling != null:
			remove_child(sibling)
			rig.add_child(sibling)
			stack_carry = sibling
		else:
			stack_carry = StackCarry.new()
			stack_carry.name = "StackCarry"
			rig.add_child(stack_carry)

func reset_position() -> void:
	global_position = _camp_builder.get_hero_spawn_pos() if _camp_builder != null else Vector3(1.6, 0.0, 0.5)
	rig.rotation.y = -PI * 0.5
	_mine_timer = 0.0
	_in_drop_anim = false
	if stack_carry != null:
		stack_carry.clear_all()

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity = Vector3.ZERO
		_virtual_joy = Vector2.ZERO
		rig.set_tools_visible(false)
		rig.play_anim("Idle", 0.12, 1.0)
		return
	_handle_movement(delta)
	_handle_water_and_mining(delta)
	_handle_camp_interactions(delta)
	_update_animations(delta)

func _handle_movement(delta: float) -> void:
	var key_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3.ZERO
	if first_person_controls:
		var forward_horiz := Vector3(sin(_fp_yaw), 0.0, cos(_fp_yaw))
		var right_horiz := forward_horiz.cross(Vector3.UP).normalized()
		move_dir = forward_horiz * (-key_vec.y) + right_horiz * key_vec.x
	else:
		var raw_input := key_vec
		if _virtual_joy.length() > 0.05:
			raw_input = _virtual_joy

		var screen_right := Vector3(1.0, 0.0, -1.0).normalized()
		var screen_up := Vector3(-1.0, 0.0, -1.0).normalized()
		move_dir = screen_right * raw_input.x + screen_up * (-raw_input.y)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var spd := carry_speed if not stack_carry.is_empty() else move_speed
	velocity = move_dir * spd
	if velocity.length_squared() > 0.0001:
		move_and_slide()

	var next_pos := global_position
	var r_min_x := _camp_builder.river_min_x if _camp_builder != null else -3.45
	var c_max_x := _camp_builder.camp_max_x if _camp_builder != null else 6.2
	var r_min_z := _camp_builder.river_min_z if _camp_builder != null else -6.5
	var r_max_z := _camp_builder.river_max_z if _camp_builder != null else 3.82
	var c_min_z := _camp_builder.camp_min_z if _camp_builder != null else -3.62
	var c_max_z := _camp_builder.camp_max_z if _camp_builder != null else 3.78

	next_pos.x = clampf(next_pos.x, r_min_x, c_max_x)
	if next_pos.x < 0.0:
		next_pos.z = clampf(next_pos.z, r_min_z, r_max_z)
	else:
		next_pos.z = clampf(next_pos.z, c_min_z, c_max_z)

	var table_pos := _chef_station.global_position if _chef_station != null else GameState.CHEF_TABLE_POS
	var table_dx := next_pos.x - table_pos.x
	var table_dz := next_pos.z - table_pos.z
	if absf(table_dx) < 0.55 and absf(table_dz) < 0.72:
		if absf(table_dx) > absf(table_dz):
			next_pos.x = table_pos.x + signf(table_dx) * 0.55
		else:
			next_pos.z = table_pos.z + signf(table_dz) * 0.72

	var target_y := (GameState.WATER_Y + 0.03) if next_pos.x < 0.0 else GameState.CAMP_Y
	next_pos.y = lerpf(global_position.y, target_y, minf(1.0, delta * 14.0))
	global_position = next_pos

	if first_person_controls:
		rig.rotation.y = _fp_yaw
	elif move_dir.length_squared() > 0.01:
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, minf(1.0, delta * 14.0))

func _handle_water_and_mining(delta: float) -> void:
	var on_river := global_position.x < 0.12
	var can_mine := on_river and stack_carry.is_empty()

	if on_river and velocity.length() > 0.6:
		_splash_timer += delta
		if _splash_timer >= 0.11:
			_splash_timer = 0.0
			if _vfx != null:
				_vfx.spawn_water_splash(Vector3(global_position.x, GameState.WATER_Y + 0.04, global_position.z), 2, 0.75)

	_mine_timer = maxf(0.0, _mine_timer - delta)

	# --- Temporary First-Person Mode ---
	if first_person_controls:
		var can_fp_swing := stack_carry.is_empty()
		rig.set_tools_visible(can_fp_swing)
		var want_swing := _fp_attack_queued or _fp_attack_held
		_fp_attack_queued = false
		if can_fp_swing and want_swing and _mine_timer <= 0.0:
			_mine_timer = mine_interval
			_dual_swing = not _dual_swing
			var fp_anim := "Mine_Dual_Strike" if _dual_swing else "Mine_Strike"
			rig.play_anim(fp_anim, 0.06, 1.3, true)

			var forward_horiz := Vector3(sin(_fp_yaw), 0.0, cos(_fp_yaw))
			var fp_target: Node3D = null
			if _river_ice_system != null and _river_ice_system.has_method("find_nearest_block"):
				fp_target = _river_ice_system.find_nearest_block(global_position + forward_horiz * 0.75, mine_range)
				if fp_target == null:
					fp_target = _river_ice_system.find_nearest_block(global_position, mine_range)
			if fp_target != null:
				var fp_block_wr: WeakRef = weakref(fp_target)
				get_tree().create_timer(0.16).timeout.connect(func() -> void:
					if not can_process():
						return
					var b := fp_block_wr.get_ref() as Node3D
					if b != null and b.has_method("take_hit"):
						b.take_hit(mine_damage, global_position)
				)
		return
	# -----------------------------------

	var target_block: Node3D = null
	if can_mine and _river_ice_system != null and _river_ice_system.has_method("find_nearest_block"):
		target_block = _river_ice_system.find_nearest_block(global_position, mine_range)

	rig.set_tools_visible(on_river and stack_carry.is_empty())

	if target_block != null and _mine_timer <= 0.0:
		_mine_timer = mine_interval
		var to_block := target_block.global_position - global_position
		to_block.y = 0.0
		if to_block.length_squared() > 0.001:
			rig.rotation.y = atan2(to_block.x, to_block.z)
		_dual_swing = not _dual_swing
		var anim_name := "Mine_Dual_Strike" if _dual_swing else "Mine_Strike"
		rig.play_anim(anim_name, 0.06, 1.3, true)

		var block_wr: WeakRef = weakref(target_block)
		get_tree().create_timer(0.16).timeout.connect(func() -> void:
			if not can_process():
				return
			var b := block_wr.get_ref() as Node3D
			if b != null and b.has_method("take_hit"):
				b.take_hit(mine_damage, global_position)
		)

func _handle_camp_interactions(delta: float) -> void:
	_pickup_timer = maxf(0.0, _pickup_timer - delta)
	_unload_timer = maxf(0.0, _unload_timer - delta)
	_serve_timer = maxf(0.0, _serve_timer - delta)
	if _drop_anim_timer > 0.0:
		_drop_anim_timer -= delta
		if _drop_anim_timer <= 0.0:
			_in_drop_anim = false

	var raw_pad_pos := _camp_builder.get_raw_fish_pad_pos() if _camp_builder != null else GameState.RAW_FISH_PAD_POS
	var input_pad_pos := _camp_builder.get_chef_input_pad_pos() if _camp_builder != null else GameState.CHEF_INPUT_PAD_POS
	var output_pad_pos := _camp_builder.get_chef_output_pad_pos() if _camp_builder != null else GameState.CHEF_OUTPUT_PAD_POS
	var serve_pos := _camp_builder.get_serve_trigger_pos() if _camp_builder != null else GameState.SERVE_TRIGGER_POS
	var cash_pos := _camp_builder.get_cash_zone_pos() if _camp_builder != null else GameState.CASH_ZONE_POS

	# 1. Pick up raw fish from shoreline pad
	if _chef_station != null and _dist_xz(global_position, raw_pad_pos) < 1.05:
		if _pickup_timer <= 0.0:
			if stack_carry.can_accept(GameState.ItemType.RAW_TUNA):
				var fish_type: int = _chef_station.pop_shore_fish()
				if fish_type != -1:
					_pickup_timer = 0.09
					SoundManager.play("pop", 1.15, -9.0)
					stack_carry.push_item(fish_type)

	# 2. Drop raw fish at ChefInputPad
	if _chef_station != null and _dist_xz(global_position, input_pad_pos) < 1.1:
		if _unload_timer <= 0.0 and stack_carry.is_holding_raw():
			var from_p := stack_carry.get_top_hand_world_pos()
			var dropped := stack_carry.pop_item()
			if dropped != -1:
				_unload_timer = 0.08
				_in_drop_anim = true
				_drop_anim_timer = 0.22
				rig.play_anim("Drop_Unload", 0.06, 1.6, true)
				_chef_station.receive_raw_fish(dropped, from_p)

	# 3. Pick up cooked steaks from ChefOutputPad
	if _chef_station != null and _dist_xz(global_position, output_pad_pos) < 1.05:
		if _pickup_timer <= 0.0:
			if stack_carry.can_accept(GameState.ItemType.TUNA_STEAK):
				if _chef_station.pop_ready_steak():
					_pickup_timer = 0.07
					SoundManager.play("pop", 1.15, -9.0)
					stack_carry.push_item(GameState.ItemType.TUNA_STEAK)

	# 4. Serve customers from ServeTriggerZone
	var on_serve := _dist_xz(global_position, serve_pos) < 0.95
	if _camp_builder != null:
		_camp_builder.set_serve_zone_active(on_serve and stack_carry.is_holding_steaks())

	if on_serve and _customer_system != null and stack_carry.is_holding_steaks():
		if _serve_timer <= 0.0 and _customer_system.has_method("can_serve_front") and _customer_system.can_serve_front():
			var from_pos := stack_carry.get_top_hand_world_pos()
			stack_carry.pop_item()
			_serve_timer = 0.11
			_customer_system.serve_front_customer(from_pos)

	# 5. Collect cash at CashZone
	if _cash_zone != null and _dist_xz(global_position, cash_pos) < 1.35:
		if _cash_zone.has_method("collect_towards"):
			_cash_zone.collect_towards(stack_carry)

func _update_animations(_delta: float) -> void:
	if _in_drop_anim:
		return
	if _mine_timer > 0.15:
		return
	var moving := velocity.length() > 0.25
	var carrying := not stack_carry.is_empty()
	if moving:
		rig.play_anim("Run_Carry" if carrying else "Run", 0.1, 1.15 if carrying else 1.25)
	else:
		rig.play_anim("Idle_Carry" if carrying else "Idle", 0.12, 1.0)

func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
