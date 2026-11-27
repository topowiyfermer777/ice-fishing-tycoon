extends Node3D
class_name CharacterRig

const LOOP_ANIMS := ["Idle", "Idle_Carry", "Run", "Run_Carry", "Walk", "Chop"]
const IGNORE_ANIMS := ["Chef_Arm_L", "Chef_Arm_R"]

var model_root: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var _attached_tools: Array[Node3D] = []
var _anim_map: Dictionary = {}
var _current_anim: String = ""

func setup_model(glb_scene: PackedScene, outline_category: int) -> void:
	setup_existing_or_spawn(glb_scene, outline_category)

func setup_existing_or_spawn(glb_scene: PackedScene, outline_category: int) -> void:
	var existing := get_node_or_null("Model") as Node3D
	if existing != null:
		model_root = existing
	else:
		if model_root != null:
			model_root.queue_free()
		model_root = glb_scene.instantiate() as Node3D
		model_root.name = "Model"
		add_child(model_root)

	OutlineHelper.apply(model_root, outline_category, false)

	skeleton = _find_typed(model_root, "Skeleton3D") as Skeleton3D
	anim_player = _find_typed(model_root, "AnimationPlayer") as AnimationPlayer
	_configure_animations()

func attach_tool(bone_name: String, tool_scene: PackedScene, pos: Vector3, quat: Quaternion, scl: Vector3) -> Node3D:
	if skeleton == null:
		push_warning("CharacterRig: Skeleton3D not found, cannot attach tool to %s" % bone_name)
		return null
	var attach_name := "Attach_%s" % bone_name.replace(".", "_")
	var existing_attach := skeleton.get_node_or_null(attach_name) as BoneAttachment3D
	if existing_attach != null:
		if existing_attach.get_child_count() > 0:
			var first := existing_attach.get_child(0) as Node3D
			if first != null and not (first in _attached_tools):
				_attached_tools.append(first)
			return first
	else:
		existing_attach = BoneAttachment3D.new()
		existing_attach.name = attach_name
		existing_attach.bone_name = bone_name
		skeleton.add_child(existing_attach)

	var tool_inst := tool_scene.instantiate() as Node3D
	OutlineHelper.apply(tool_inst, OutlineConfig.Category.TOOL, true)
	tool_inst.position = pos
	tool_inst.quaternion = quat
	tool_inst.scale = scl
	existing_attach.add_child(tool_inst)
	_attached_tools.append(tool_inst)
	return tool_inst

func set_tools_visible(vis: bool) -> void:
	for t in _attached_tools:
		if is_instance_valid(t):
			t.visible = vis

func play_anim(anim_name: String, blend: float = 0.12, speed: float = 1.0, force_restart: bool = false) -> void:
	if anim_player == null:
		return
	var resolved: String = _anim_map.get(anim_name, "")
	if resolved.is_empty():
		return
	if _current_anim == resolved and anim_player.is_playing() and not force_restart:
		anim_player.speed_scale = speed
		return
	_current_anim = resolved
	anim_player.speed_scale = speed
	anim_player.play(resolved, blend)

func _configure_animations() -> void:
	_anim_map.clear()
	if anim_player == null:
		return
	for raw_name in anim_player.get_animation_list():
		var short_name := raw_name.get_slice("/", raw_name.get_slice_count("/") - 1)
		if short_name in IGNORE_ANIMS:
			continue
		_anim_map[short_name] = raw_name
		var anim := anim_player.get_animation(raw_name)
		if anim != null:
			if short_name in LOOP_ANIMS:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE

func _find_typed(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for c in node.get_children():
		var found := _find_typed(c, type_name)
		if found != null:
			return found
	return null
