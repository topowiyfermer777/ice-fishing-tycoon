extends Node3D
class_name UpgradePad

signal purchased(pad: UpgradePad)

const CASH_BUNDLE_SCENE := preload("res://exports/glb/Stations_And_UI/Cash_Bundle.glb")

@export var pad_id: String = ""
@export var cost: int = 100
@export var start_active: bool = true
@export var pad_scene: PackedScene
@export var pad_scale: float = 1.28

var remaining_cost: int = 100
var total_cost: int = 100
var is_active: bool = true

var _visual: Node3D
var _label: Label3D
var _brackets_mesh: MeshInstance3D
var _brackets_mat: StandardMaterial3D
var _player: PlayerController
var _pay_timer: float = 0.0

func setup(scene: PackedScene, p_cost: int, player: PlayerController, p_start_active: bool = true) -> void:
	pad_scene = scene
	cost = p_cost
	total_cost = p_cost
	remaining_cost = p_cost
	_player = player
	start_active = p_start_active
	is_active = p_start_active
	visible = p_start_active

func bind_player(player: PlayerController) -> void:
	_player = player

func set_cost(new_cost: int) -> void:
	cost = new_cost
	total_cost = new_cost
	remaining_cost = new_cost
	_update_label()

func set_active(active: bool) -> void:
	is_active = active
	visible = active
	if active:
		scale = Vector3.ONE * (pad_scale * 0.1)
		create_tween().tween_property(self, "scale", Vector3.ONE * pad_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	total_cost = cost
	remaining_cost = cost
	is_active = start_active
	visible = start_active
	scale = Vector3.ONE * pad_scale

	_visual = get_node_or_null("PadModel") as Node3D
	if _visual == null and pad_scene != null:
		_visual = pad_scene.instantiate() as Node3D
		_visual.name = "PadModel"
		add_child(_visual)
	if _visual != null:
		_configure_pad_meshes(_visual)
		OutlineHelper.apply(_visual, OutlineConfig.Category.STATION, true)

	_label = get_node_or_null("PriceLabel") as Label3D
	if _label == null:
		_label = Label3D.new()
		_label.name = "PriceLabel"
		add_child(_label)
	_label.position = Vector3(0.62, 0.044, 0.0)
	_label.rotation_degrees = Vector3(-90.0, 90.0, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_label.shaded = false
	_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	_label.render_priority = 6
	_label.font_size = 82
	_label.pixel_size = 0.0044
	_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_label.outline_modulate = Color(0.08, 0.12, 0.18, 1.0)
	_label.outline_size = 22
	_label.no_depth_test = false
	var old_bg := get_node_or_null("PriceBadgeBg")
	if old_bg != null:
		old_bg.queue_free()
	_update_label()

func _configure_pad_meshes(root: Node) -> void:
	for c in root.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var lname := mi.name.to_lower()
			if lname.contains("pricetext") or lname.contains("pricetag"):
				mi.visible = false
			elif lname.contains("corner_brackets"):
				_brackets_mesh = mi
				var m := mi.get_active_material(0)
				_brackets_mat = (m.duplicate() as StandardMaterial3D) if m is StandardMaterial3D else StandardMaterial3D.new()
				_brackets_mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
				mi.set_surface_override_material(0, _brackets_mat)
		_configure_pad_meshes(c)

func _process(delta: float) -> void:
	if not is_active or remaining_cost <= 0 or _player == null:
		return

	var affordable := GameState.money >= remaining_cost
	if _label != null:
		_label.modulate = Color(1.0, 0.92, 0.38, 1.0) if affordable else Color(1.0, 1.0, 1.0, 1.0)

	var dist := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var on_pad := dist < 1.02

	if _brackets_mat != null:
		if on_pad and GameState.money > 0:
			_brackets_mat.albedo_color = Color(0.25, 0.98, 0.42, 1.0)
			_brackets_mat.emission_enabled = true
			_brackets_mat.emission = Color(0.2, 0.9, 0.35, 1.0)
			_brackets_mat.emission_energy_multiplier = 1.4
		elif GameState.money >= remaining_cost:
			_brackets_mat.albedo_color = Color(0.55, 1.0, 0.65, 1.0)
			_brackets_mat.emission_enabled = false
		else:
			_brackets_mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
			_brackets_mat.emission_enabled = false

	_pay_timer = maxf(0.0, _pay_timer - delta)
	if on_pad and GameState.money > 0 and _pay_timer <= 0.0:
		_pay_timer = 0.045
		var step := mini(10, mini(remaining_cost, GameState.money))
		if step > 0 and GameState.spend_money(step):
			remaining_cost -= step
			_update_label()
			var prog := 1.0 - float(remaining_cost) / float(maxi(1, total_cost))
			SoundManager.play("pad_tick", 0.85 + prog * 0.55, -7.0)
			_spawn_pay_bill()
			if remaining_cost <= 0:
				is_active = false
				SoundManager.play("build", 1.0, -3.0)
				purchased.emit(self)

func _spawn_pay_bill() -> void:
	var bill := CASH_BUNDLE_SCENE.instantiate() as Node3D
	OutlineHelper.apply(bill, OutlineConfig.Category.CASH, true)
	bill.scale = Vector3.ONE * 0.65
	get_parent().add_child(bill)
	var from_p := _player.stack_carry.get_cash_top_world_pos()
	var to_p := global_position + Vector3(0.0, 0.1, 0.0)
	var bill_wr: WeakRef = weakref(bill)
	ParabolaFlight.launch(self, bill, from_p, to_p, 0.16, 0.5, func() -> void:
		var b := bill_wr.get_ref() as Node3D
		if b != null:
			b.queue_free()
	)

func _update_label() -> void:
	if _label != null:
		_label.text = "$%d" % maxi(0, remaining_cost)
