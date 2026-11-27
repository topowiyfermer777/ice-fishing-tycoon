extends RefCounted
class_name ParabolaFlight

static func launch(
	_host: Node,
	node: Node3D,
	start_pos: Vector3,
	end_pos: Vector3,
	duration: float,
	arc_height: float,
	on_complete: Callable = Callable(),
	spin_speed: float = 0.0,
	sparkle_trail: bool = false,
	vfx: Node = null
) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.global_position = start_pos
	var state := { "last_sparkle": 0.0 }
	var node_wr: WeakRef = weakref(node)
	var vfx_wr: WeakRef = weakref(vfx) if vfx != null else null
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void:
		var target := node_wr.get_ref() as Node3D
		if target == null:
			return
		var p := start_pos.lerp(end_pos, t)
		p.y += sin(t * PI) * arc_height
		target.global_position = p
		if spin_speed != 0.0:
			target.rotate_y(spin_speed * 0.016)
		if sparkle_trail and vfx_wr != null and (t - state["last_sparkle"]) > 0.11:
			state["last_sparkle"] = t
			var vfx_obj := vfx_wr.get_ref() as Node
			if vfx_obj != null and vfx_obj.has_method("spawn_sparkle"):
				vfx_obj.spawn_sparkle(p)
	, 0.0, 1.0, maxf(0.05, duration))
	if on_complete.is_valid():
		tween.tween_callback(on_complete)
