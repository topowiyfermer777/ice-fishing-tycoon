extends Camera3D
class_name CameraRig

const OFFSET := Vector3(10.2, 12.6, 10.2)
const DEFAULT_TARGET := Vector3(1.5, 0.0, -0.35)
const ISO_FOV := 34.0
const ISO_NEAR := 0.5
const ISO_FAR := 120.0

const MENU_CAM_POS := Vector3(-0.65, 3.05, 3.55)
const MENU_CAM_LOOK := Vector3(-4.75, 0.35, -3.05)
const MENU_FOV := 36.0

# --- Temporary First-Person Mode (remove this block + FirstPersonCameraMode to revert) ---
enum CameraMode { ISOMETRIC, FIRST_PERSON }

@export var camera_mode: CameraMode = CameraMode.ISOMETRIC:
	set(value):
		camera_mode = value
		if is_inside_tree():
			_apply_camera_mode()

var _fp_mode := FirstPersonCameraMode.new()
# -----------------------------------------------------------------------------------------

var follow_target: Node3D
var _current_look := DEFAULT_TARGET
var in_menu: bool = false
var _menu_blend: float = 0.0
var _menu_time: float = 0.0
var _menu_tween: Tween

func _ready() -> void:
	_apply_camera_mode()
	if camera_mode == CameraMode.ISOMETRIC and _menu_blend <= 0.001:
		global_position = _current_look + OFFSET
		look_at(_current_look, Vector3.UP)

func set_menu_mode(enabled: bool, instant: bool = false) -> void:
	if enabled and camera_mode == CameraMode.FIRST_PERSON:
		camera_mode = CameraMode.ISOMETRIC
	in_menu = enabled
	if _menu_tween != null and _menu_tween.is_valid():
		_menu_tween.kill()
	var target_blend := 1.0 if enabled else 0.0
	if instant:
		_menu_blend = target_blend
		_update_menu_iso_transform(0.0)
	else:
		var dur := 0.55 if enabled else 0.75
		_menu_tween = create_tween()
		_menu_tween.tween_property(self, "_menu_blend", target_blend, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if in_menu:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_V:
			camera_mode = CameraMode.FIRST_PERSON if camera_mode == CameraMode.ISOMETRIC else CameraMode.ISOMETRIC
			get_viewport().set_input_as_handled()
			return
	if camera_mode == CameraMode.FIRST_PERSON and _fp_mode.handle_input(event):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if camera_mode == CameraMode.FIRST_PERSON and not in_menu and _menu_blend <= 0.001:
		_fp_mode.update(self, follow_target, delta)
		return
	_update_menu_iso_transform(delta)

func _update_menu_iso_transform(delta: float) -> void:
	var desired := DEFAULT_TARGET
	if is_instance_valid(follow_target):
		var p := follow_target.global_position
		desired = Vector3(
			clampf(p.x * 0.55 + 0.65, -0.9, 3.2),
			0.0,
			clampf(p.z * 0.55 - 0.35, -2.6, 1.8)
		)
	_current_look = _current_look.lerp(desired, minf(1.0, delta * 5.2))
	var iso_pos := _current_look + OFFSET

	if _menu_blend <= 0.001:
		fov = ISO_FOV
		global_position = iso_pos
		look_at(_current_look, Vector3.UP)
		return

	_menu_time += delta
	var menu_pos := MENU_CAM_POS + Vector3(sin(_menu_time * 0.28) * 0.10, sin(_menu_time * 0.19) * 0.08, 0.0)
	fov = lerpf(ISO_FOV, MENU_FOV, _menu_blend)
	global_position = iso_pos.lerp(menu_pos, _menu_blend)
	look_at(_current_look.lerp(MENU_CAM_LOOK, _menu_blend), Vector3.UP)

func _apply_camera_mode() -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		_fp_mode.activate(self, follow_target)
	else:
		_fp_mode.deactivate(follow_target)
		fov = ISO_FOV
		near = ISO_NEAR
		far = ISO_FAR

func _exit_tree() -> void:
	_fp_mode.deactivate(follow_target)
