extends Node3D
class_name CashZone

const CASH_BUNDLE_SCENE := preload("res://exports/glb/Stations_And_UI/Cash_Bundle.glb")
const CASH_SCALE := 0.72
const MAX_FLOOR_BUNDLES := 240

var _piles: Array[Node3D] = []
var _pile_values: Array[int] = []
var _collect_timer: float = 0.0
var _cash_sfx_timer: float = 0.0

func _ready() -> void:
	GameState.game_reset.connect(reset)

func reset() -> void:
	for p in _piles:
		if is_instance_valid(p):
			p.queue_free()
	_piles.clear()
	_pile_values.clear()

func spawn_cash_drop(from_pos: Vector3, amount: int) -> void:
	var bundles := maxi(1, int(amount / 10))
	for b in range(bundles):
		if _piles.size() >= MAX_FLOOR_BUNDLES and not _pile_values.is_empty():
			_pile_values[-1] += (bundles - b) * 10
			return
		var node := CASH_BUNDLE_SCENE.instantiate() as Node3D
		OutlineHelper.apply(node, OutlineConfig.Category.CASH, true)
		node.scale = Vector3.ONE * CASH_SCALE
		node.rotation.y = randf_range(-0.2, 0.2)
		add_child(node)

		var idx := _piles.size()
		var col := idx % 4
		var row := int(idx / 4) % 3
		var layer := int(idx / 12)
		var dest := global_position + Vector3(
			(float(col) - 1.5) * 0.24,
			0.03 + float(layer) * 0.098,
			(float(row) - 1.0) * 0.36
		)
		_piles.append(node)
		_pile_values.append(10)

		ParabolaFlight.launch(self, node, from_pos, dest, 0.32 + float(b) * 0.04, 1.05)

func _process(delta: float) -> void:
	_collect_timer = maxf(0.0, _collect_timer - delta)
	_cash_sfx_timer = maxf(0.0, _cash_sfx_timer - delta)

func collect_towards(stack_carry: StackCarry) -> void:
	if _piles.is_empty() or _collect_timer > 0.0:
		return
	_collect_timer = 0.032

	var batch := mini(3, _piles.size())
	var target_pos := stack_carry.get_cash_top_world_pos()
	for i in range(batch):
		var node: Node3D = _piles.pop_back()
		var val: int = _pile_values.pop_back()
		if is_instance_valid(node):
			var start_pos := node.global_position
			var node_wr: WeakRef = weakref(node)
			ParabolaFlight.launch(self, node, start_pos, target_pos, 0.16, 0.45, func() -> void:
				var n := node_wr.get_ref() as Node3D
				if n != null:
					n.queue_free()
				GameState.add_money(val)
				if _cash_sfx_timer <= 0.0:
					_cash_sfx_timer = 0.065
					SoundManager.play("cash", 1.0 + randf_range(0.0, 0.15), -7.0)
			)
		else:
			GameState.add_money(val)
