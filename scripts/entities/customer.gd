extends Node3D
class_name CustomerUnit

const YELLOW_SCENE := preload("res://exports/glb/Characters/Customer_Yellow.glb")
const TEAL_SCENE := preload("res://exports/glb/Characters/Customer_Teal.glb")
const WHITE_SCENE := preload("res://exports/glb/Characters/Customer_White.glb")
const ORDER_BUBBLE_TEX := preload("res://assets/ui/order_bubble_steak.png")

var rig: CharacterRig
var lane_index: int = 0
var slot_index: int = 0
var is_receiving: bool = false

var _bubble: Sprite3D
var _bubble_shown: bool = false
var _wave_timer: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO
var _walking: bool = false

func setup(variant: int, lane: int, slot: int) -> void:
	lane_index = lane
	slot_index = slot
	var prefab: PackedScene = YELLOW_SCENE
	if variant == 1:
		prefab = TEAL_SCENE
	elif variant == 2:
		prefab = WHITE_SCENE

	rig = get_node_or_null("CustomerRig") as CharacterRig
	if rig == null:
		rig = CharacterRig.new()
		rig.name = "CustomerRig"
		add_child(rig)

	if variant != 0:
		var old_model := rig.get_node_or_null("Model")
		if old_model != null:
			rig.remove_child(old_model)
			old_model.queue_free()

	rig.setup_existing_or_spawn(prefab, OutlineConfig.Category.CHARACTER)
	rig.scale = Vector3.ONE
	rig.play_anim("Idle", 0.05, randf_range(0.9, 1.1))

	_bubble = get_node_or_null("OrderBubble") as Sprite3D
	if _bubble == null:
		_build_speech_bubble()
	else:
		_bubble.visible = false
	_bubble_shown = false

	_wave_timer = randf_range(1.0, 4.0)

func _build_speech_bubble() -> void:
	_bubble = Sprite3D.new()
	_bubble.name = "OrderBubble"
	_bubble.position = Vector3(0.0, 1.36, 0.0)
	_bubble.offset = Vector2(125.0, 0.0)
	_bubble.pixel_size = 0.00125
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.shaded = false
	_bubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bubble.texture = ORDER_BUBBLE_TEX
	add_child(_bubble)
	_bubble.visible = false

func set_queue_position(pos: Vector3, snap: bool) -> void:
	_target_pos = pos
	if snap:
		global_position = pos
		_walking = false
		if rig != null:
			rig.play_anim("Idle", 0.1, 1.0)
	else:
		_walking = true
		if rig != null:
			rig.play_anim("Walk", 0.08, 1.3)
	if _bubble != null:
		var should_show := (slot_index == 0 and not is_receiving)
		_bubble.visible = should_show
		if should_show and not _bubble_shown:
			_bubble_shown = true
			_bubble.scale = Vector3.ONE * 0.15
			_bubble.create_tween().tween_property(_bubble, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not should_show:
			_bubble_shown = false

func _process(delta: float) -> void:
	if _walking:
		global_position = global_position.move_toward(_target_pos, 2.2 * delta)
		if global_position.distance_to(_target_pos) < 0.02:
			global_position = _target_pos
			_walking = false
			if rig != null and not is_receiving:
				rig.play_anim("Idle", 0.1, 1.0)
	elif slot_index == 0 and not is_receiving:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = randf_range(2.6, 5.2)
			if rig != null:
				rig.play_anim("Wave", 0.1, 1.2, true)
		if _bubble != null:
			_bubble.position.y = 1.36 + sin(Time.get_ticks_msec() * 0.005 + float(lane_index) * 1.2) * 0.045

func play_receive() -> void:
	is_receiving = true
	_bubble_shown = false
	if _bubble != null:
		_bubble.visible = false
	if rig != null:
		rig.play_anim("Receive", 0.06, 1.4, true)
