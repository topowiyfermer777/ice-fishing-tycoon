extends CanvasLayer
class_name MainMenu

signal play_pressed
signal restart_pressed
signal sound_toggled
signal quit_pressed
signal easter_egg_triggered(first_time: bool)

const SNOW_COUNT := 34
const EASTER_EGG_STEP := 10

@onready var root: Control = $Root
@onready var snow_overlay: Control = $Root/SnowOverlay
@onready var brand_row: Control = $Root/MenuColumn/BrandRow
@onready var emblem_icon: Control = $Root/MenuColumn/BrandRow/EmblemIcon
@onready var title_box: Control = $Root/MenuColumn/TitleBox
@onready var accent_bar: Control = $Root/MenuColumn/AccentBar
@onready var play_btn: Button = $Root/MenuColumn/ButtonsBox/PlayButton
@onready var play_icon: Control = $Root/MenuColumn/ButtonsBox/PlayButton/Icon
@onready var restart_btn: Button = $Root/MenuColumn/ButtonsBox/RestartButton
@onready var restart_icon: Control = $Root/MenuColumn/ButtonsBox/RestartButton/Icon
@onready var sound_btn: Button = $Root/MenuColumn/ButtonsBox/SoundButton
@onready var sound_icon: Control = $Root/MenuColumn/ButtonsBox/SoundButton/Icon
@onready var quit_btn: Button = $Root/MenuColumn/ButtonsBox/QuitButton
@onready var quit_icon: Control = $Root/MenuColumn/ButtonsBox/QuitButton/Icon
@onready var ice_counter_pill: PanelContainer = $Root/IceCounterPill
@onready var ice_counter_icon: Control = $Root/IceCounterPill/Row/Icon
@onready var ice_counter_label: Label = $Root/IceCounterPill/Row/CountLabel
@onready var easter_egg_toast: PanelContainer = $Root/EasterEggToast
@onready var easter_egg_label: Label = $Root/EasterEggToast/ToastLabel

var _menu_open: bool = true
var _menu_ice_broken: int = 0
var _easter_egg_unlocked: bool = false
var _gold_snow_timer: float = 0.0
var _fade_tween: Tween
var _entrance_tween: Tween
var _counter_tween: Tween
var _toast_tween: Tween
var _snowflakes: Array[Dictionary] = []

func _ready() -> void:
	play_btn.pressed.connect(func() -> void: play_pressed.emit())
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	sound_btn.pressed.connect(_on_sound_pressed)
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())

	snow_overlay.draw.connect(_on_draw_snow)
	emblem_icon.draw.connect(_on_draw_emblem_icon)
	play_icon.draw.connect(_on_draw_play_icon)
	restart_icon.draw.connect(_on_draw_restart_icon)
	sound_icon.draw.connect(_on_draw_sound_icon)
	quit_icon.draw.connect(_on_draw_quit_icon)
	ice_counter_icon.draw.connect(_on_draw_counter_ice_icon)

	for btn in [play_btn, restart_btn, sound_btn, quit_btn]:
		_bind_hover_anim(btn)

	_init_snowflakes()
	refresh_sound_label()

func _process(delta: float) -> void:
	if not visible or _snowflakes.is_empty():
		return
	_gold_snow_timer = maxf(0.0, _gold_snow_timer - delta)
	for flake in _snowflakes:
		flake["phase"] = float(flake["phase"]) + delta * 1.4
		flake["y"] = float(flake["y"]) + float(flake["speed_y"]) * delta
		flake["x"] = float(flake["x"]) + (float(flake["drift_x"]) + sin(float(flake["phase"])) * 0.012) * delta
		if float(flake["y"]) > 1.03:
			flake["y"] = -0.03
			flake["x"] = randf()
		if float(flake["x"]) < -0.02:
			flake["x"] = 1.02
		elif float(flake["x"]) > 1.02:
			flake["x"] = -0.02
	snow_overlay.queue_redraw()

func show_menu(can_continue: bool, instant: bool = false) -> void:
	_menu_open = true
	play_btn.text = "Продолжить" if can_continue else "Играть"
	restart_btn.visible = can_continue
	refresh_sound_label()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	visible = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if instant:
		root.modulate.a = 1.0
		_reset_entrance_states(1.0)
		return

	root.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(root, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play_staggered_entrance()

func hide_menu(instant: bool = false) -> void:
	_menu_open = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()

	if instant:
		root.modulate.a = 0.0
		visible = false
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(root, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(func() -> void:
		if not _menu_open:
			visible = false
	)

func refresh_sound_label() -> void:
	if is_instance_valid(sound_btn):
		sound_btn.text = "Звук: Выкл" if SoundManager.muted else "Звук: Вкл"
	if is_instance_valid(sound_icon):
		sound_icon.queue_redraw()

func increment_ice_broken() -> void:
	_menu_ice_broken += 1
	ice_counter_label.text = str(_menu_ice_broken)
	if not ice_counter_pill.visible:
		ice_counter_pill.visible = true
		ice_counter_pill.modulate.a = 0.0
		ice_counter_pill.create_tween().tween_property(ice_counter_pill, "modulate:a", 1.0, 0.22)

	ice_counter_pill.pivot_offset = ice_counter_pill.size * 0.5
	if _counter_tween != null and _counter_tween.is_valid():
		_counter_tween.kill()
	_counter_tween = ice_counter_pill.create_tween()
	_counter_tween.tween_property(ice_counter_pill, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_counter_tween.tween_property(ice_counter_pill, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if _menu_ice_broken > 0 and _menu_ice_broken % EASTER_EGG_STEP == 0:
		var first_time := not _easter_egg_unlocked
		_easter_egg_unlocked = true
		_gold_snow_timer = 3.8
		ice_counter_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45, 1.0))
		ice_counter_icon.queue_redraw()
		_show_easter_egg_toast(
			"★ Ребята из Южного Парка вышли на берег!" if first_time else ("★ Ребята машут тебе с берега!  (%d)" % _menu_ice_broken)
		)
		easter_egg_triggered.emit(first_time)

func reset_easter_egg() -> void:
	_menu_ice_broken = 0
	_easter_egg_unlocked = false
	_gold_snow_timer = 0.0
	ice_counter_label.text = "0"
	ice_counter_label.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	ice_counter_pill.visible = false
	easter_egg_toast.visible = false
	ice_counter_icon.queue_redraw()

func _show_easter_egg_toast(msg: String) -> void:
	easter_egg_label.text = msg
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	easter_egg_toast.visible = true
	easter_egg_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(easter_egg_toast, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(3.4)
	_toast_tween.tween_property(easter_egg_toast, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(func() -> void: easter_egg_toast.visible = false)

func _on_sound_pressed() -> void:
	SoundManager.toggle_muted()
	refresh_sound_label()
	sound_toggled.emit()

func _bind_hover_anim(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void:
		if not visible or not _menu_open:
			return
		btn.pivot_offset = btn.size * 0.5
		btn.create_tween().tween_property(btn, "scale", Vector2(1.03, 1.03), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		SoundManager.play("pop", 1.32, -18.0)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
		btn.create_tween().tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)

func _reset_entrance_states(alpha_val: float) -> void:
	for item in [brand_row, title_box, accent_bar, play_btn, restart_btn, sound_btn, quit_btn]:
		if is_instance_valid(item):
			item.modulate.a = alpha_val
			item.scale = Vector2.ONE

func _play_staggered_entrance() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	var items: Array[Control] = [brand_row, title_box, accent_bar, play_btn]
	if restart_btn.visible:
		items.append(restart_btn)
	items.append(sound_btn)
	items.append(quit_btn)

	for item in items:
		item.modulate.a = 0.0
		item.pivot_offset = item.size * 0.5
		item.scale = Vector2(0.94, 0.94)

	_entrance_tween = create_tween()
	_entrance_tween.set_parallel(true)
	for i in range(items.size()):
		var delay := float(i) * 0.045
		_entrance_tween.tween_property(items[i], "modulate:a", 1.0, 0.24).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_entrance_tween.tween_property(items[i], "scale", Vector2.ONE, 0.28).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _init_snowflakes() -> void:
	_snowflakes.clear()
	for i in range(SNOW_COUNT):
		_snowflakes.append({
			"x": randf(),
			"y": randf(),
			"radius": randf_range(1.4, 3.6),
			"speed_y": randf_range(0.025, 0.068),
			"drift_x": randf_range(-0.015, 0.018),
			"alpha": randf_range(0.18, 0.52),
			"phase": randf() * TAU,
		})

func _on_draw_snow() -> void:
	var sz := snow_overlay.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return
	var gold_blend := minf(1.0, _gold_snow_timer * 0.6)
	for i in range(_snowflakes.size()):
		var flake: Dictionary = _snowflakes[i]
		var pos := Vector2(float(flake["x"]) * sz.x, float(flake["y"]) * sz.y)
		var col := Color(0.92, 0.97, 1.0, float(flake["alpha"]))
		if gold_blend > 0.01 and i % 2 == 0:
			col = col.lerp(Color(1.0, 0.86, 0.36, minf(0.92, float(flake["alpha"]) + 0.32)), gold_blend)
		snow_overlay.draw_circle(pos, float(flake["radius"]), col)

func _on_draw_emblem_icon() -> void:
	var c := emblem_icon.size * 0.5
	var col := Color(0.58, 0.89, 1.0, 0.96)
	_draw_crystal_shape(emblem_icon, c, 10.5, col, 1.8)

func _on_draw_counter_ice_icon() -> void:
	var c := ice_counter_icon.size * 0.5
	var col := Color(1.0, 0.86, 0.34, 0.98) if _easter_egg_unlocked else Color(0.58, 0.89, 1.0, 0.96)
	_draw_crystal_shape(ice_counter_icon, c, 7.5, col, 1.6)

func _draw_crystal_shape(canvas: Control, c: Vector2, r: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := float(i) * PI / 3.0 - PI * 0.5
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	pts.append(pts[0])
	canvas.draw_polyline(pts, col, width, true)
	for i in range(3):
		var a := float(i) * PI / 3.0 - PI * 0.5
		var p1 := c + Vector2(cos(a), sin(a)) * (r * 0.58)
		var p2 := c - Vector2(cos(a), sin(a)) * (r * 0.58)
		canvas.draw_line(p1, p2, Color(col.r, col.g, col.b, col.a * 0.72), maxf(1.2, width * 0.75), true)

func _on_draw_play_icon() -> void:
	var c := play_icon.size * 0.5
	var tri := PackedVector2Array([
		c + Vector2(-4.5, -6.5),
		c + Vector2(7.0, 0.0),
		c + Vector2(-4.5, 6.5),
	])
	play_icon.draw_colored_polygon(tri, Color(0.07, 0.14, 0.24, 0.96))

func _on_draw_restart_icon() -> void:
	var c := restart_icon.size * 0.5
	var col := Color(0.86, 0.94, 1.0, 0.94)
	var r := 6.8
	restart_icon.draw_arc(c, r, -PI * 0.72, PI * 0.85, 20, col, 1.9, true)
	var tip := c + Vector2(cos(-PI * 0.72), sin(-PI * 0.72)) * r
	var head := PackedVector2Array([
		tip + Vector2(-1.8, -2.2),
		tip + Vector2(3.8, -1.0),
		tip + Vector2(0.4, 3.4),
	])
	restart_icon.draw_colored_polygon(head, col)

func _on_draw_sound_icon() -> void:
	var c := sound_icon.size * 0.5
	var col := Color(0.86, 0.94, 1.0, 0.94)
	var cone := PackedVector2Array([
		c + Vector2(-7.0, -3.0),
		c + Vector2(-3.5, -3.0),
		c + Vector2(1.0, -6.5),
		c + Vector2(1.0, 6.5),
		c + Vector2(-3.5, 3.0),
		c + Vector2(-7.0, 3.0),
	])
	sound_icon.draw_colored_polygon(cone, col)
	if SoundManager.muted:
		sound_icon.draw_line(c + Vector2(3.0, -4.0), c + Vector2(8.0, 4.0), Color(1.0, 0.54, 0.54, 0.95), 1.9, true)
		sound_icon.draw_line(c + Vector2(8.0, -4.0), c + Vector2(3.0, 4.0), Color(1.0, 0.54, 0.54, 0.95), 1.9, true)
	else:
		sound_icon.draw_arc(c + Vector2(1.5, 0.0), 4.2, -0.75, 0.75, 10, col, 1.7, true)
		sound_icon.draw_arc(c + Vector2(1.5, 0.0), 7.4, -0.82, 0.82, 12, col, 1.7, true)

func _on_draw_quit_icon() -> void:
	var c := quit_icon.size * 0.5
	var col := Color(0.86, 0.94, 1.0, 0.94)
	var frame := PackedVector2Array([
		c + Vector2(-1.0, -6.5),
		c + Vector2(-6.5, -6.5),
		c + Vector2(-6.5, 6.5),
		c + Vector2(-1.0, 6.5),
	])
	quit_icon.draw_polyline(frame, col, 1.8, true)
	quit_icon.draw_line(c + Vector2(-2.0, 0.0), c + Vector2(6.5, 0.0), col, 1.8, true)
	quit_icon.draw_line(c + Vector2(3.5, -3.5), c + Vector2(6.8, 0.0), col, 1.8, true)
	quit_icon.draw_line(c + Vector2(3.5, 3.5), c + Vector2(6.8, 0.0), col, 1.8, true)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _menu_open:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER or key.physical_keycode == KEY_SPACE):
			play_pressed.emit()
			get_viewport().set_input_as_handled()
