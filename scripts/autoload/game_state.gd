extends Node

enum ItemType {
	RAW_TUNA,
	GIANT_TUNA,
	TUNA_STEAK,
}

signal money_changed(new_amount: int)
signal dam_built_signal
signal conveyor_built_signal
signal worker_hired_signal(worker_index: int)
signal game_reset

const LOG_DAM_COST := 100
const CONVEYOR_COST := 200
const WORKER_COSTS: Array[int] = [200, 200, 350, 500]
const MAX_WORKERS := 4

const STEAK_PRICE := 20
const NORMAL_ICE_HP := 4
const GIANT_ICE_HP := 9
const NORMAL_STEAKS_PER_FISH := 3
const GIANT_STEAKS_PER_SEGMENT := 3 # 5 segments * 3 = 15 steaks

# World layout coordinates (single source of truth, easily extensible for future zones)
const WATER_Y := -0.18
const LAKE_Y := -2.62
const CAMP_Y := 0.0
const CLIFF_Z := 4.4
const DAM_Z := 3.95
const RIVER_MIN_X := -3.8
const RIVER_MAX_X := 0.0

const RAW_FISH_PAD_POS := Vector3(1.3, 0.0, 1.8)
const CHEF_INPUT_PAD_POS := Vector3(3.2, 0.0, 1.25)
const CHEF_TABLE_POS := Vector3(3.2, 0.0, 0.1)
const CHEF_OUTPUT_PAD_POS := Vector3(3.2, 0.0, -1.2)
const SERVE_TRIGGER_POS := Vector3(3.8, 0.0, -3.1)
const SERVING_COUNTER_POS := Vector3(3.8, 0.0, -3.9)
const CASH_ZONE_POS := Vector3(1.7, 0.0, -2.7)

const LOG_DAM_PAD_POS := Vector3(0.95, 0.0, 3.25)
const CONVEYOR_PAD_POS := Vector3(0.95, 0.0, 3.25)
const ADD_WORKER_PAD_POS := Vector3(0.95, 0.0, -1.75)

var money: int = 0
var dam_built: bool = false
var conveyor_built: bool = false
var workers_hired: int = 0

func _ready() -> void:
	_ensure_input_actions()

func reset_state() -> void:
	money = 0
	dam_built = false
	conveyor_built = false
	workers_hired = 0
	money_changed.emit(money)
	game_reset.emit()

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if amount <= 0 or money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

func mark_dam_built() -> void:
	if dam_built:
		return
	dam_built = true
	dam_built_signal.emit()

func mark_conveyor_built() -> void:
	if conveyor_built:
		return
	conveyor_built = true
	conveyor_built_signal.emit()

func add_worker() -> int:
	if workers_hired >= MAX_WORKERS:
		return -1
	var idx := workers_hired
	workers_hired += 1
	worker_hired_signal.emit(idx)
	return idx

func get_next_worker_cost() -> int:
	if workers_hired >= WORKER_COSTS.size():
		return -1
	return WORKER_COSTS[workers_hired]

func _ensure_input_actions() -> void:
	var bindings := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"toggle_fullscreen": [KEY_F11],
		"restart_game": [KEY_R],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for key_code in bindings[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key_code
				InputMap.action_add_event(action, ev)
