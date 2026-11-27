extends Node3D
class_name ConveyorSystem

const TUNA_V2_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_v2.glb")
const TUNA_STEAK_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_Steak.glb")

@export var belt_speed: float = 1.75

const BELT_Y := 0.285
const DEFAULT_INPUT_WAYPOINTS := [
	Vector3(1.05, BELT_Y, 2.46),
	Vector3(2.85, BELT_Y, 2.46),
	Vector3(3.15, BELT_Y, 2.36),
	Vector3(3.20, BELT_Y, 2.11),
]
const DEFAULT_OUTPUT_WAYPOINTS := [
	Vector3(3.2, BELT_Y, -0.52),
	Vector3(3.2, BELT_Y, -3.52),
]

var _chef_station: ChefStation
var _customer_system: CustomerQueueSystem
var _vfx: VfxManager
var _belt_visuals: Node3D
var _belt_pieces: Array[Dictionary] = []
var _belt_slats: Array[MeshInstance3D] = []

var _input_waypoints: Array[Vector3] = []
var _output_waypoints: Array[Vector3] = []

var _input_items: Array[Dictionary] = []
var _output_items: Array[Dictionary] = []
var _pull_shore_timer: float = 0.0
var _pull_steak_timer: float = 0.0

func setup(chef: ChefStation, customers: CustomerQueueSystem, vfx: VfxManager) -> void:
	_chef_station = chef
	_customer_system = customers
	_vfx = vfx

func _ready() -> void:
	_belt_visuals = get_node_or_null("ConveyorVisuals") as Node3D
	if _belt_visuals != null:
		for c in _belt_visuals.get_children():
			if c is Node3D:
				var piece := c as Node3D
				OutlineHelper.apply(piece, OutlineConfig.Category.STATION, true)
				_collect_slats(piece)
				_belt_pieces.append({
					"node": piece,
					"scale": piece.scale,
					"pos": piece.position,
				})
		_belt_visuals.visible = false

	_read_waypoints()
	GameState.conveyor_built_signal.connect(_on_conveyor_built)
	GameState.game_reset.connect(reset)

func _read_waypoints() -> void:
	_input_waypoints.clear()
	var in_node := get_node_or_null("InputWaypoints")
	if in_node != null:
		for c in in_node.get_children():
			if c is Marker3D:
				_input_waypoints.append((c as Marker3D).global_position)
	if _input_waypoints.is_empty():
		for p in DEFAULT_INPUT_WAYPOINTS:
			_input_waypoints.append(p)

	_output_waypoints.clear()
	var out_node := get_node_or_null("OutputWaypoints")
	if out_node != null:
		for c in out_node.get_children():
			if c is Marker3D:
				_output_waypoints.append((c as Marker3D).global_position)
	if _output_waypoints.is_empty():
		for p in DEFAULT_OUTPUT_WAYPOINTS:
			_output_waypoints.append(p)

func reset() -> void:
	if _belt_visuals != null:
		_belt_visuals.visible = false
		for entry in _belt_pieces:
			var n: Node3D = entry["node"]
			if is_instance_valid(n):
				n.scale = entry["scale"]
				n.position = entry["pos"]

	for e in _input_items:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_input_items.clear()
	for e in _output_items:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_output_items.clear()

func _on_conveyor_built() -> void:
	if _belt_visuals == null:
		return
	_belt_visuals.visible = true
	for i in range(_belt_pieces.size()):
		var entry: Dictionary = _belt_pieces[i]
		var inst: Node3D = entry["node"]
		if not is_instance_valid(inst):
			continue
		var target_scale: Vector3 = entry["scale"]
		var world_pos := inst.global_position
		inst.scale = target_scale * 0.01

		var delay := float(i) * 0.05
		var tw := inst.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(inst, "scale", target_scale, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _vfx != null:
			tw.tween_callback(func() -> void:
				_vfx.spawn_sparkle(world_pos + Vector3(0.0, 0.3, 0.0))
			)

func _collect_slats(root: Node) -> void:
	for c in root.get_children():
		if c is MeshInstance3D and c.name.to_lower().contains("slat"):
			_belt_slats.append(c as MeshInstance3D)
		_collect_slats(c)

func get_input_start_pos() -> Vector3:
	return _input_waypoints[0] if not _input_waypoints.is_empty() else DEFAULT_INPUT_WAYPOINTS[0]

func enqueue_input_fish(fish_type: int) -> void:
	var fish := TUNA_V2_SCENE.instantiate() as Node3D
	OutlineHelper.apply(fish, OutlineConfig.Category.FISH, true)
	var scl := 1.35 if fish_type == GameState.ItemType.GIANT_TUNA else 0.88
	fish.scale = Vector3.ONE * scl
	fish.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(fish)
	fish.global_position = get_input_start_pos()
	_input_items.append({ "node": fish, "type": fish_type, "waypoints": _input_waypoints, "seg": 0, "dist": 0.0, "ready": true })

func enqueue_output_steak(from_pos: Vector3) -> void:
	var steak := TUNA_STEAK_SCENE.instantiate() as Node3D
	OutlineHelper.apply(steak, OutlineConfig.Category.STEAK, true)
	add_child(steak)
	var start_wp: Vector3 = _output_waypoints[0]
	var item := { "node": steak, "type": GameState.ItemType.TUNA_STEAK, "waypoints": _output_waypoints, "seg": 0, "dist": 0.0, "ready": false }
	_output_items.append(item)
	ParabolaFlight.launch(self, steak, from_pos, start_wp, 0.18, 0.35, func() -> void:
		item["ready"] = true
	)

func _process(delta: float) -> void:
	if not GameState.conveyor_built:
		return

	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.014)
	for s in _belt_slats:
		if is_instance_valid(s):
			s.position.y = pulse * 0.004

	_pull_shore_timer -= delta
	if _pull_shore_timer <= 0.0 and _chef_station != null and _chef_station.has_shore_fish() and _input_items.size() < 8:
		_pull_shore_timer = 0.32
		var fish_type := _chef_station.pop_shore_fish()
		if fish_type != -1:
			_spawn_input_fish(fish_type)

	_pull_steak_timer -= delta
	if _pull_steak_timer <= 0.0 and _chef_station != null and _chef_station.has_ready_steak() and _output_items.size() < 12:
		_pull_steak_timer = 0.25
		if _chef_station.pop_ready_steak():
			enqueue_output_steak(_chef_station.global_position + Vector3(0.0, 0.3, -0.5))

	_advance_items(_input_items, delta, true)
	_advance_items(_output_items, delta, false)

func _spawn_input_fish(fish_type: int) -> void:
	var fish := TUNA_V2_SCENE.instantiate() as Node3D
	OutlineHelper.apply(fish, OutlineConfig.Category.FISH, true)
	var scl := 1.35 if fish_type == GameState.ItemType.GIANT_TUNA else 0.88
	fish.scale = Vector3.ONE * scl
	fish.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(fish)
	var shore_start := _chef_station.get_next_shore_slot_pos() if _chef_station != null else _input_waypoints[0]
	var item := { "node": fish, "type": fish_type, "waypoints": _input_waypoints, "seg": 0, "dist": 0.0, "ready": false }
	_input_items.append(item)
	ParabolaFlight.launch(self, fish, shore_start, _input_waypoints[0], 0.18, 0.45, func() -> void:
		item["ready"] = true
	)

func _advance_items(list: Array[Dictionary], delta: float, is_input: bool) -> void:
	for i in range(list.size() - 1, -1, -1):
		var item: Dictionary = list[i]
		if not item.get("ready", true):
			continue
		var node: Node3D = item["node"]
		if not is_instance_valid(node):
			list.remove_at(i)
			continue

		var wps: Array = item["waypoints"]
		var seg: int = item["seg"]
		if seg >= wps.size() - 1:
			if is_input:
				var ftype: int = item["type"]
				var from_p := node.global_position
				node.queue_free()
				list.remove_at(i)
				if _chef_station != null:
					_chef_station.receive_raw_fish(ftype, from_p)
			else:
				if _customer_system != null and _customer_system.can_serve_front():
					var from_p := node.global_position
					node.queue_free()
					list.remove_at(i)
					_customer_system.serve_front_customer(from_p)
			continue

		var a: Vector3 = wps[seg]
		var b: Vector3 = wps[seg + 1]
		var seg_len := a.distance_to(b)
		var d: float = item["dist"] + belt_speed * delta
		if d >= seg_len:
			item["seg"] = seg + 1
			item["dist"] = d - seg_len
			node.global_position = b
		else:
			item["dist"] = d
			node.global_position = a.lerp(b, d / maxf(seg_len, 0.001))
