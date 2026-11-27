extends Node3D
class_name CampBuilder

@export var camp_min_x: float = 0.0
@export var camp_max_x: float = 6.2
@export var camp_min_z: float = -3.62
@export var camp_max_z: float = 3.78
@export var river_min_x: float = -3.45
@export var river_min_z: float = -6.5
@export var river_max_z: float = 3.82

@onready var expandable_fence_east: Node3D = get_node_or_null("ExpandableFenceEast") as Node3D

@onready var _raw_fish_marker: Marker3D = get_node_or_null("Zones/RawFishPad") as Marker3D
@onready var _chef_input_marker: Marker3D = get_node_or_null("Zones/ChefInputPad") as Marker3D
@onready var _chef_output_marker: Marker3D = get_node_or_null("Zones/ChefOutputPad") as Marker3D
@onready var _serve_marker: Marker3D = get_node_or_null("Zones/ServeTriggerZone") as Marker3D
@onready var _cash_marker: Marker3D = get_node_or_null("Zones/CashZone") as Marker3D
@onready var _hero_spawn_marker: Marker3D = get_node_or_null("Zones/HeroSpawn") as Marker3D
@onready var _worker_spawn_marker: Marker3D = get_node_or_null("Zones/WorkerSpawn") as Marker3D

var _serve_highlight_mat: StandardMaterial3D

func _ready() -> void:
	var counter := get_node_or_null("ServingCounter")
	if counter != null:
		OutlineHelper.apply(counter, OutlineConfig.Category.STATION, true)

	var static_fence := get_node_or_null("FenceStatic")
	if static_fence != null:
		OutlineHelper.apply(static_fence, OutlineConfig.Category.FENCE, true)

	if expandable_fence_east != null:
		OutlineHelper.apply(expandable_fence_east, OutlineConfig.Category.FENCE, true)

	var serve_frame := get_node_or_null("FloorPads/ServeTriggerFrame") as MeshInstance3D
	if serve_frame != null:
		var base := serve_frame.get_active_material(0)
		if base is StandardMaterial3D:
			_serve_highlight_mat = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			serve_frame.material_override = _serve_highlight_mat

	GameState.conveyor_built_signal.connect(func() -> void: _set_conveyor_replaced_pads_visible(false))
	GameState.game_reset.connect(func() -> void: _set_conveyor_replaced_pads_visible(true))

func _set_conveyor_replaced_pads_visible(vis: bool) -> void:
	for path in [
		"FloorPads/RawFishBase",
		"FloorPads/RawFishFrame",
		"FloorPads/ChefOutputBase",
		"FloorPads/ChefOutputFrame",
	]:
		var n := get_node_or_null(path) as Node3D
		if n != null:
			n.visible = vis

func set_serve_zone_active(active: bool) -> void:
	if _serve_highlight_mat == null:
		return
	if active:
		_serve_highlight_mat.albedo_color = Color(0.2, 0.92, 0.35, 1.0)
		_serve_highlight_mat.emission = Color(0.2, 0.92, 0.35, 1.0)
		_serve_highlight_mat.emission_energy_multiplier = 1.6
	else:
		_serve_highlight_mat.albedo_color = Color(0.18, 0.52, 0.25, 0.85)
		_serve_highlight_mat.emission = Color(0.12, 0.4, 0.18, 1.0)
		_serve_highlight_mat.emission_energy_multiplier = 0.4

func get_raw_fish_pad_pos() -> Vector3:
	return _raw_fish_marker.global_position if _raw_fish_marker != null else GameState.RAW_FISH_PAD_POS

func get_chef_input_pad_pos() -> Vector3:
	return _chef_input_marker.global_position if _chef_input_marker != null else GameState.CHEF_INPUT_PAD_POS

func get_chef_output_pad_pos() -> Vector3:
	return _chef_output_marker.global_position if _chef_output_marker != null else GameState.CHEF_OUTPUT_PAD_POS

func get_serve_trigger_pos() -> Vector3:
	return _serve_marker.global_position if _serve_marker != null else GameState.SERVE_TRIGGER_POS

func get_cash_zone_pos() -> Vector3:
	return _cash_marker.global_position if _cash_marker != null else GameState.CASH_ZONE_POS

func get_hero_spawn_pos() -> Vector3:
	return _hero_spawn_marker.global_position if _hero_spawn_marker != null else Vector3(1.6, 0.0, 0.5)

func get_worker_spawn_pos() -> Vector3:
	return _worker_spawn_marker.global_position if _worker_spawn_marker != null else Vector3(0.45, 0.0, -1.35)
