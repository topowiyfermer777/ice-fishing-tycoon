extends Node3D
class_name RiverIceSystem

signal menu_block_broken

const ICE_BLOCK_SCENE := preload("res://scenes/entities/ice_block.tscn")
const TUNA_V2_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_v2.glb")
const CUSTOMER_WHITE_SCENE := preload("res://exports/glb/Characters/Customer_White.glb")
const HERO_COLLISION_RADIUS := 0.38
const WORKER_COLLISION_RADIUS := 0.34

@export var max_active_blocks: int = 11
@export var max_lake_blocks: int = 8
@export var spawn_interval: float = 2.35
@export var giant_every_n: int = 4
@export var initial_block_zs: PackedFloat32Array = PackedFloat32Array([-0.4, -2.5, -5.2, -7.8])

var _blocks: Array[IceBlock] = []
var _lake_blocks: Array[IceBlock] = []
var _spawn_timer: float = 0.0
var _spawn_count: int = 0
var _vfx: VfxManager
var _chef_station: ChefStation
var _river: RiverBuilder
var _conveyor_system: ConveyorSystem
var _hero: Node3D
var _workers_container: Node3D
var _prev_actor_pos: Dictionary = {}
var menu_mode: bool = false
var _easter_egg_group: Node3D
var _easter_egg_rigs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func setup(vfx: VfxManager, chef: ChefStation, river: RiverBuilder = null, conveyor: ConveyorSystem = null) -> void:
	_vfx = vfx
	_chef_station = chef
	_river = river
	_conveyor_system = conveyor

func set_actors(hero: Node3D, workers_container: Node3D) -> void:
	_hero = hero
	_workers_container = workers_container

func set_menu_mode(enabled: bool) -> void:
	menu_mode = enabled
	if is_instance_valid(_easter_egg_group):
		_easter_egg_group.visible = enabled

func _ready() -> void:
	process_priority = 10
	_rng.randomize()
	GameState.game_reset.connect(reset)
	call_deferred("reset")

func reset() -> void:
	for b in _blocks:
		if is_instance_valid(b):
			b.queue_free()
	_blocks.clear()
	for lb in _lake_blocks:
		if is_instance_valid(lb):
			lb.queue_free()
	_lake_blocks.clear()
	_clear_easter_egg_squad()
	_spawn_timer = 0.5
	_spawn_count = 0

	var water_y := _river.get_water_y() if _river != null else GameState.WATER_Y
	var seed_xs := [-1.3, -2.6, -1.1, -2.8]
	for i in range(initial_block_zs.size()):
		var sx: float = seed_xs[i % seed_xs.size()]
		var giant := (i == 1)
		_spawn_block(Vector3(sx, water_y, initial_block_zs[i]), giant)

	var lake_seeds := [
		Vector2(-3.8, 6.8),
		Vector2(-1.4, 7.6),
		Vector2(-2.9, 8.9),
		Vector2(0.4, 7.1),
	]
	for idx in range(lake_seeds.size()):
		var lpos: Vector2 = lake_seeds[idx]
		var lb := _spawn_block_node(Vector3(lpos.x, GameState.LAKE_Y, lpos.y), idx == 2)
		lb.enter_lake(GameState.LAKE_Y, true)
		_lake_blocks.append(lb)

func _process(delta: float) -> void:
	_cleanup_invalid()
	_resolve_actor_collisions(delta, true)
	_resolve_block_collisions()
	_resolve_actor_collisions(0.0, false)
	_resolve_lake_collisions()

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _blocks.size() < max_active_blocks:
		_spawn_timer = spawn_interval
		_spawn_count += 1
		var giant := (giant_every_n > 0 and _spawn_count % giant_every_n == 0)
		var x_range := _river.get_spawn_x_range() if _river != null else Vector2(-2.95, -0.85)
		var sz := _river.get_spawn_z() if _river != null else -13.2
		var wy := _river.get_water_y() if _river != null else GameState.WATER_Y
		var rx := _rng.randf_range(x_range.x, x_range.y)
		_spawn_block(Vector3(rx, wy, sz), giant)

func spawn_cheat_block(giant: bool = true) -> void:
	var wy := _river.get_water_y() if _river != null else GameState.WATER_Y
	var rx := _rng.randf_range(-2.6, -1.0)
	_spawn_block(Vector3(rx, wy, -2.2), giant)

func find_nearest_block(from_pos: Vector3, max_range: float) -> IceBlock:
	var best: IceBlock = null
	var best_d := max_range
	for b in _blocks:
		if not is_instance_valid(b) or b.is_falling or b.in_lake or b.hp <= 0:
			continue
		var d := Vector2(b.global_position.x - from_pos.x, b.global_position.z - from_pos.z).length() - (b.radius - 0.5)
		if d <= best_d:
			best_d = d
			best = b
	return best

func find_worker_target(from_pos: Vector3, current_target: IceBlock = null) -> IceBlock:
	var best: IceBlock = null
	var best_score := 1e9
	for b in _blocks:
		if not is_instance_valid(b) or b.is_falling or b.in_lake or b.hp <= 0:
			continue
		if b.global_position.z < -7.5 or b.global_position.z > 4.0:
			continue
		var d := Vector2(b.global_position.x - from_pos.x, b.global_position.z - from_pos.z).length()
		var crowding := float(b.reserved_workers) * 3.0
		if b == current_target:
			crowding -= 2.2
		var downstream_bonus := -b.global_position.z * 0.35
		var score := d + crowding + downstream_bonus
		if score < best_score:
			best_score = score
			best = b
	return best

func find_block_along_ray(ray_origin: Vector3, ray_dir: Vector3) -> IceBlock:
	var dir := ray_dir.normalized()
	var best: IceBlock = null
	var best_t := 1e9
	for b in _blocks:
		if not is_instance_valid(b) or b.is_falling or b.in_lake or b.hp <= 0:
			continue
		var center := b.global_position + Vector3(0.0, 0.36 * (b.radius / 0.55), 0.0)
		var to_center := center - ray_origin
		var t := to_center.dot(dir)
		if t < 0.0:
			continue
		var hit_r := b.radius * 1.28
		var dist_sq := to_center.length_squared() - t * t
		if dist_sq <= hit_r * hit_r and t < best_t:
			best_t = t
			best = b
	return best

func trigger_menu_easter_egg() -> void:
	SoundManager.play("build", 1.12, -3.0)
	if is_instance_valid(_easter_egg_group):
		for entry in _easter_egg_rigs:
			var node: Node3D = entry["node"]
			if not is_instance_valid(node):
				continue
			if _vfx != null:
				_vfx.spawn_customer_puff(node.global_position)
			var base_y: float = float(entry["base_y"])
			var hop := node.create_tween()
			hop.tween_property(node, "position:y", base_y + 0.34, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			hop.tween_property(node, "position:y", base_y, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		return

	_easter_egg_group = Node3D.new()
	_easter_egg_group.name = "SouthParkEasterEgg"
	_easter_egg_group.visible = menu_mode
	add_child(_easter_egg_group)
	_easter_egg_rigs.clear()

	var lineup := [
		{ "id": SouthParkStyle.CharacterId.STAN, "pos": Vector3(-4.25, 0.0, -3.65) },
		{ "id": SouthParkStyle.CharacterId.KYLE, "pos": Vector3(-4.25, 0.0, -4.25) },
		{ "id": SouthParkStyle.CharacterId.CARTMAN, "pos": Vector3(-4.30, 0.0, -4.88) },
		{ "id": SouthParkStyle.CharacterId.KENNY, "pos": Vector3(-4.25, 0.0, -5.48) },
	]

	for i in range(lineup.size()):
		var spec: Dictionary = lineup[i]
		var char_id: int = int(spec["id"])
		var spawn_pos: Vector3 = spec["pos"]

		var holder := Node3D.new()
		holder.position = spawn_pos
		var to_cam := CameraRig.MENU_CAM_POS - spawn_pos
		to_cam.y = 0.0
		if to_cam.length_squared() > 0.001:
			holder.rotation.y = atan2(to_cam.x, to_cam.z)

		var target_scale := SouthParkStyle.get_scale(char_id, false)
		holder.scale = Vector3.ONE * 0.05
		holder.visible = false
		_easter_egg_group.add_child(holder)

		var rig := CharacterRig.new()
		rig.name = "Rig"
		holder.add_child(rig)
		rig.setup_existing_or_spawn(CUSTOMER_WHITE_SCENE, OutlineConfig.Category.CHARACTER)
		SouthParkStyle.apply_to_customer(rig.model_root, char_id)
		SouthParkStyle.attach_hat(rig, char_id)
		rig.play_anim("Wave", 0.08, randf_range(0.95, 1.15), true)
		if rig.anim_player != null:
			var rig_wr: WeakRef = weakref(rig)
			rig.anim_player.animation_finished.connect(func(_anim_name: StringName) -> void:
				var r := rig_wr.get_ref() as CharacterRig
				if r != null and r.is_inside_tree():
					r.play_anim("Wave", 0.1, randf_range(0.95, 1.15), true)
			)

		_easter_egg_rigs.append({
			"node": holder,
			"base_y": spawn_pos.y,
		})

		var holder_wr: WeakRef = weakref(holder)
		var vfx_wr: WeakRef = weakref(_vfx)
		var delay := float(i) * 0.13
		var pop_tw := holder.create_tween()
		pop_tw.tween_interval(delay)
		pop_tw.tween_callback(func() -> void:
			var h := holder_wr.get_ref() as Node3D
			if h == null:
				return
			h.visible = true
			SoundManager.play("pop", 1.0 + float(i) * 0.08, -6.0)
			var v := vfx_wr.get_ref() as VfxManager
			if v != null:
				v.spawn_customer_puff(h.global_position)
		)
		pop_tw.tween_property(holder, "scale", target_scale, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clear_easter_egg_squad() -> void:
	_easter_egg_rigs.clear()
	if is_instance_valid(_easter_egg_group):
		_easter_egg_group.queue_free()
	_easter_egg_group = null

func _spawn_block_node(pos: Vector3, giant: bool) -> IceBlock:
	var block := ICE_BLOCK_SCENE.instantiate() as IceBlock
	var dz := _river.get_dam_z() if _river != null else GameState.DAM_Z
	var cz := _river.get_cliff_z() if _river != null else GameState.CLIFF_Z
	block.setup(giant, _vfx, dz, cz)
	add_child(block)
	block.global_position = pos
	return block

func _spawn_block(pos: Vector3, giant: bool) -> void:
	var block := _spawn_block_node(pos, giant)
	block.broken.connect(_on_block_broken)
	block.fell_off_waterfall.connect(_on_block_fell)
	_blocks.append(block)

func _on_block_broken(block: IceBlock, is_giant: bool, world_pos: Vector3) -> void:
	_blocks.erase(block)
	if menu_mode:
		if _vfx != null:
			_vfx.spawn_water_splash(Vector3(world_pos.x, GameState.WATER_Y + 0.04, world_pos.z), 5, 1.1 if is_giant else 0.85)
		menu_block_broken.emit()
		return
	if _chef_station == null:
		return

	if is_giant:
		_launch_fish_to_shore(world_pos + Vector3(0.0, 0.5, 0.0), GameState.ItemType.GIANT_TUNA, 0.0)
		_launch_fish_to_shore(world_pos + Vector3(0.25, 0.35, 0.0), GameState.ItemType.RAW_TUNA, 0.12)
	else:
		_launch_fish_to_shore(world_pos + Vector3(0.0, 0.35, 0.0), GameState.ItemType.RAW_TUNA, 0.0)

func _launch_fish_to_shore(start_pos: Vector3, fish_type: int, delay: float) -> void:
	var fish := TUNA_V2_SCENE.instantiate() as Node3D
	OutlineHelper.apply(fish, OutlineConfig.Category.FISH, true)
	var scl := 1.55 if fish_type == GameState.ItemType.GIANT_TUNA else 0.95
	fish.scale = Vector3.ONE * scl
	fish.rotation = Vector3(0.0, PI * 0.5, PI * 0.5)
	add_child(fish)
	fish.visible = false

	var to_conveyor := GameState.conveyor_built and _conveyor_system != null
	var dest := _conveyor_system.get_input_start_pos() if to_conveyor else _chef_station.get_next_shore_slot_pos()
	var fish_wr: WeakRef = weakref(fish)
	var tw := fish.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		var f := fish_wr.get_ref() as Node3D
		if f == null:
			return
		f.visible = true
		SoundManager.play("fish_whoosh", 0.9 if fish_type == GameState.ItemType.GIANT_TUNA else 1.1, -7.0)
		ParabolaFlight.launch(
			self,
			f,
			start_pos,
			dest,
			0.48,
			1.55,
			func() -> void:
				var f2 := fish_wr.get_ref() as Node3D
				if f2 != null:
					f2.queue_free()
				if to_conveyor and _conveyor_system != null:
					_conveyor_system.enqueue_input_fish(fish_type)
				elif _chef_station != null:
					_chef_station.add_shore_fish(fish_type),
			6.0,
			true,
			_vfx
		)
	)

func _on_block_fell(block: IceBlock) -> void:
	_blocks.erase(block)
	if not is_instance_valid(block):
		return
	if not (block in _lake_blocks):
		_lake_blocks.append(block)
	while _lake_blocks.size() > max_lake_blocks:
		var oldest := _lake_blocks.pop_front() as IceBlock
		if is_instance_valid(oldest):
			oldest.sink_and_free()

func _cleanup_invalid() -> void:
	for i in range(_blocks.size() - 1, -1, -1):
		if not is_instance_valid(_blocks[i]):
			_blocks.remove_at(i)
	for i in range(_lake_blocks.size() - 1, -1, -1):
		if not is_instance_valid(_lake_blocks[i]):
			_lake_blocks.remove_at(i)

func _resolve_actor_collisions(delta: float, apply_impulse: bool) -> void:
	if menu_mode:
		return
	var actors: Array[Dictionary] = []
	var active_ids: Dictionary = {}
	if is_instance_valid(_hero) and _hero.global_position.x < 0.25:
		var hid := _hero.get_instance_id()
		active_ids[hid] = true
		var hpos := Vector2(_hero.global_position.x, _hero.global_position.z)
		actors.append({ "id": hid, "pos": hpos, "radius": HERO_COLLISION_RADIUS, "vel": Vector2.ZERO })

	if is_instance_valid(_workers_container):
		for w in _workers_container.get_children():
			if w is Node3D and is_instance_valid(w) and w.global_position.x < 0.25:
				var wid := w.get_instance_id()
				active_ids[wid] = true
				var wpos := Vector2(w.global_position.x, w.global_position.z)
				actors.append({ "id": wid, "pos": wpos, "radius": WORKER_COLLISION_RADIUS, "vel": Vector2.ZERO })

	if apply_impulse and delta > 0.0001:
		for actor in actors:
			var aid: int = actor["id"]
			var cur_pos: Vector2 = actor["pos"]
			if _prev_actor_pos.has(aid):
				actor["vel"] = (cur_pos - (_prev_actor_pos[aid] as Vector2)) / delta
			_prev_actor_pos[aid] = cur_pos
		for old_id in _prev_actor_pos.keys():
			if not active_ids.has(old_id):
				_prev_actor_pos.erase(old_id)

	if actors.is_empty():
		return

	var dz := _river.get_dam_z() if _river != null else GameState.DAM_Z
	for b in _blocks:
		if not is_instance_valid(b) or b.is_falling or b.in_lake or b.hp <= 0:
			continue
		var max_z := (dz - b.radius - 0.08) if GameState.dam_built else 4.2
		for actor in actors:
			var apos: Vector2 = actor["pos"]
			var aradius: float = actor["radius"]
			var avel: Vector2 = actor["vel"]
			var diff := Vector2(b.global_position.x - apos.x, b.global_position.z - apos.y)
			var min_d := b.radius + aradius
			var dist := diff.length()
			if dist < min_d:
				var n := (diff / dist) if dist > 0.001 else Vector2(0.0, -1.0)
				var pen := min_d - dist
				b.global_position.x = clampf(b.global_position.x + n.x * pen, -3.35, -0.52)
				b.global_position.z = minf(b.global_position.z + n.y * pen, max_z)

				if apply_impulse:
					var approach := maxf(0.0, avel.dot(n))
					var mass_factor := 0.62 if b.is_giant else 1.0
					if approach > 0.25:
						b.apply_push_impulse(n * clampf((approach * 0.72 + 0.75) * mass_factor, 0.65, 2.8))
					else:
						if n.y < -0.25:
							b.damp_forward_push()
						if absf(n.x) > 0.35:
							b.apply_push_impulse(Vector2(n.x * 0.45 * mass_factor, 0.0))

func _resolve_lake_collisions() -> void:
	var count := _lake_blocks.size()
	for i in range(count):
		var a := _lake_blocks[i]
		if not is_instance_valid(a):
			continue
		for j in range(i + 1, count):
			var b := _lake_blocks[j]
			if not is_instance_valid(b):
				continue
			var diff := Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
			var min_d := (a.radius + b.radius) * 1.15
			var dist := diff.length()
			if dist < min_d:
				var n := diff / maxf(dist, 0.001)
				if dist < 0.001:
					n = Vector2(1.0, 0.0)
				var push := (min_d - dist) * 0.45
				a.global_position.x = clampf(a.global_position.x - n.x * push, -7.0, 4.2)
				a.global_position.z = clampf(a.global_position.z - n.y * push, 6.15, 11.5)
				b.global_position.x = clampf(b.global_position.x + n.x * push, -7.0, 4.2)
				b.global_position.z = clampf(b.global_position.z + n.y * push, 6.15, 11.5)
		a.global_position.x = clampf(a.global_position.x, -7.0, 4.2)
		a.global_position.z = clampf(a.global_position.z, 6.15, 11.5)

func _resolve_block_collisions() -> void:
	var dz := _river.get_dam_z() if _river != null else GameState.DAM_Z
	var count := _blocks.size()
	for i in range(count):
		var a := _blocks[i]
		if a.is_falling:
			continue
		for j in range(i + 1, count):
			var b := _blocks[j]
			if b.is_falling:
				continue
			var diff := Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
			var min_d := (a.radius + b.radius) * 1.04
			var dist := diff.length()
			if dist < min_d:
				var n := diff / maxf(dist, 0.001)
				if dist < 0.001:
					n = Vector2(1.0, 0.0)
				var push := (min_d - dist) * 0.5
				a.global_position.x = clampf(a.global_position.x - n.x * push, -3.3, -0.55)
				a.global_position.z = minf(a.global_position.z - n.y * push, (dz - a.radius - 0.08) if GameState.dam_built else 4.2)
				b.global_position.x = clampf(b.global_position.x + n.x * push, -3.3, -0.55)
				b.global_position.z = minf(b.global_position.z + n.y * push, (dz - b.radius - 0.08) if GameState.dam_built else 4.2)
