extends Node3D
class_name CustomerQueueSystem

const CUSTOMER_SCENE := preload("res://scenes/entities/customer.tscn")
const TUNA_STEAK_SCENE := preload("res://exports/glb/Food_And_Ice/Tuna_Steak.glb")

@export var rows_per_lane: int = 10
@export var row_spacing: float = 0.72

const DEFAULT_LANE_STARTS := [
	Vector3(2.95, -0.04, -4.55),
	Vector3(3.8, -0.04, -4.55),
	Vector3(4.65, -0.04, -4.55),
]

var _lane_starts: Array[Vector3] = []
var _lanes: Array = [] # Array of Array[CustomerUnit]
var _next_lane: int = 0
var _vfx: VfxManager
var _cash_zone: Node
var _rng := RandomNumberGenerator.new()

func setup(vfx: VfxManager, cash_zone: Node) -> void:
	_vfx = vfx
	_cash_zone = cash_zone

func _ready() -> void:
	_rng.randomize()
	_read_lane_markers()
	GameState.game_reset.connect(reset)
	call_deferred("reset")

func _read_lane_markers() -> void:
	_lane_starts.clear()
	var container := get_node_or_null("LaneStarts")
	if container != null:
		for c in container.get_children():
			if c is Marker3D:
				_lane_starts.append((c as Marker3D).global_position)
	if _lane_starts.is_empty():
		for p in DEFAULT_LANE_STARTS:
			_lane_starts.append(p)

func reset() -> void:
	for lane in _lanes:
		for c in lane:
			if is_instance_valid(c):
				c.queue_free()
	_lanes.clear()
	_next_lane = 0

	for l in range(_lane_starts.size()):
		var lane_arr: Array[CustomerUnit] = []
		for r in range(rows_per_lane):
			var c := CUSTOMER_SCENE.instantiate() as CustomerUnit
			var roll := _rng.randf()
			var variant := 0 if roll < 0.7 else (1 if roll < 0.85 else 2)
			add_child(c)
			c.setup(variant, l, r)
			c.set_queue_position(_slot_pos(l, r), true)
			lane_arr.append(c)
		_lanes.append(lane_arr)

func can_serve_front() -> bool:
	for l in range(_lanes.size()):
		var lane: Array = _lanes[l]
		if not lane.is_empty() and not (lane[0] as CustomerUnit).is_receiving:
			return true
	return false

func serve_front_customer(from_pos: Vector3) -> bool:
	for offset in range(_lanes.size()):
		var l := (_next_lane + offset) % _lanes.size()
		var lane: Array = _lanes[l]
		if lane.is_empty():
			continue
		var cust: CustomerUnit = lane[0]
		if cust.is_receiving:
			continue

		_next_lane = (l + 1) % _lanes.size()
		cust.is_receiving = true
		if cust._bubble != null:
			cust._bubble.visible = false

		var steak := TUNA_STEAK_SCENE.instantiate() as Node3D
		OutlineHelper.apply(steak, OutlineConfig.Category.STEAK, true)
		add_child(steak)

		var target := cust.global_position + Vector3(0.0, 0.55, 0.22)
		SoundManager.play("fish_whoosh", 1.35, -9.0)
		var steak_wr: WeakRef = weakref(steak)
		var cust_wr: WeakRef = weakref(cust)
		ParabolaFlight.launch(self, steak, from_pos, target, 0.22, 0.55, func() -> void:
			var s := steak_wr.get_ref() as Node3D
			if s != null:
				s.queue_free()
			var c := cust_wr.get_ref() as CustomerUnit
			if c != null:
				_complete_serve(l, c)
		)
		return true
	return false

func _complete_serve(lane_idx: int, cust: CustomerUnit) -> void:
	if not is_instance_valid(cust):
		return
	cust.play_receive()

	var cust_wr: WeakRef = weakref(cust)
	var finish_tw := create_tween()
	finish_tw.tween_interval(0.18)
	finish_tw.tween_callback(func() -> void:
		var c := cust_wr.get_ref() as CustomerUnit
		if c == null:
			return
		var puff_pos := c.global_position
		if _vfx != null:
			_vfx.spawn_customer_puff(puff_pos)
		SoundManager.play("pop", 1.0, -5.0)
		if _cash_zone != null and _cash_zone.has_method("spawn_cash_drop"):
			_cash_zone.spawn_cash_drop(puff_pos + Vector3(0.0, 0.35, 0.0), GameState.STEAK_PRICE)

		var lane: Array = _lanes[lane_idx]
		lane.erase(c)
		lane.append(c)
		c.is_receiving = false
		c.set_queue_position(_slot_pos(lane_idx, lane.size() - 1) + Vector3(0.0, 0.0, -0.5), true)
		for i in range(lane.size()):
			var unit: CustomerUnit = lane[i]
			unit.slot_index = i
			unit.set_queue_position(_slot_pos(lane_idx, i), false)
	)

func _slot_pos(lane: int, row: int) -> Vector3:
	var base: Vector3 = _lane_starts[lane] if lane < _lane_starts.size() else DEFAULT_LANE_STARTS[0]
	var x := base.x + sin(float(row) * 1.7 + float(lane)) * 0.07
	var z := base.z - float(row) * row_spacing
	return Vector3(x, base.y, z)
