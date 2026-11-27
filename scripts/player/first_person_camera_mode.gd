extends RefCounted
class_name FirstPersonCameraMode

## Temporary first-person camera and controls mode.
## Isolated here so it can be deleted cleanly without touching core isometric gameplay.

const FP_FOV := 72.0
const FP_NEAR := 0.06
const FP_FAR := 140.0
const EYE_HEIGHT := 0.94
const FORWARD_OFFSET := 0.30
const DEFAULT_PITCH_DEG := -10.0
const MIN_PITCH_DEG := -60.0
const MAX_PITCH_DEG := 55.0
const MOUSE_YAW_SENS := 0.0032
const MOUSE_PITCH_SENS := 0.16

var _initialized: bool = false
var _yaw: float = 0.0
var _pitch_deg: float = DEFAULT_PITCH_DEG
var _attack_held: bool = false
var _attack_queued: bool = false

func activate(cam: Camera3D, follow_target: Node3D = null) -> void:
	cam.fov = FP_FOV
	cam.near = FP_NEAR
	cam.far = FP_FAR
	reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if is_instance_valid(follow_target) and follow_target.has_method("set_first_person_controls"):
		follow_target.set_first_person_controls(true)

func deactivate(follow_target: Node3D = null) -> void:
	reset()
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(follow_target) and follow_target.has_method("set_first_person_controls"):
		follow_target.set_first_person_controls(false)

func reset() -> void:
	_initialized = false
	_pitch_deg = DEFAULT_PITCH_DEG
	_attack_held = false
	_attack_queued = false

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				_attack_held = false
				return true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				if mb.pressed:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					return true
				return false
			_attack_held = mb.pressed
			if mb.pressed:
				_attack_queued = true
			return true
	elif event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var mm := event as InputEventMouseMotion
			_yaw -= mm.relative.x * MOUSE_YAW_SENS
			_pitch_deg = clampf(_pitch_deg - mm.relative.y * MOUSE_PITCH_SENS, MIN_PITCH_DEG, MAX_PITCH_DEG)
			return true
	return false

func update(cam: Camera3D, follow_target: Node3D, _delta: float) -> void:
	if not is_instance_valid(follow_target):
		return

	if not _initialized:
		var rig := follow_target.get_node_or_null("HeroRig") as Node3D
		_yaw = rig.global_rotation.y if rig != null else follow_target.global_rotation.y
		_initialized = true
		if follow_target.has_method("set_first_person_controls"):
			follow_target.set_first_person_controls(true)

	if follow_target.has_method("set_first_person_input"):
		follow_target.set_first_person_input(_yaw, _attack_held, _attack_queued)
		_attack_queued = false

	var pitch_rad := deg_to_rad(clampf(_pitch_deg, MIN_PITCH_DEG, MAX_PITCH_DEG))
	var cos_p := cos(pitch_rad)
	var view_horiz := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var view_dir := Vector3(view_horiz.x * cos_p, sin(pitch_rad), view_horiz.z * cos_p).normalized()
	var eye_pos := follow_target.global_position + Vector3(0.0, EYE_HEIGHT, 0.0) + view_horiz * FORWARD_OFFSET

	cam.global_position = eye_pos
	cam.look_at(eye_pos + view_dir, Vector3.UP)
