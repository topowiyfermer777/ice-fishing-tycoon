extends CanvasLayer
class_name HudController

signal restart_requested
signal menu_requested
signal mute_toggled

const JOY_RADIUS := 68.0

@onready var hud_root: Control = $HudRoot
@onready var top_left_pill: PanelContainer = $HudRoot/TopLeft
@onready var cash_label: Label = $HudRoot/TopLeft/CashRow/CashLabel
@onready var mute_btn: Button = $HudRoot/TopRight/HBox/MuteButton
@onready var mute_icon: Control = $HudRoot/TopRight/HBox/MuteButton/Icon
@onready var restart_btn: Button = $HudRoot/TopRight/HBox/RestartButton
@onready var restart_icon: Control = $HudRoot/TopRight/HBox/RestartButton/Icon
@onready var menu_btn: Button = $HudRoot/TopRight/HBox/MenuButton
@onready var menu_icon: Control = $HudRoot/TopRight/HBox/MenuButton/Icon
@onready var joy_overlay: Control = $HudRoot/JoystickOverlay

var _player: PlayerController
var _dragging: bool = false
var _joy_origin := Vector2.ZERO
var _joy_current := Vector2.ZERO
var _hud_active: bool = true
var _last_money: int = 0
var _fade_tween: Tween
var _pulse_tween: Tween

func set_player(player: PlayerController) -> void:
	_player = player

func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.game_reset.connect(_on_game_reset)

	mute_btn.pressed.connect(_on_mute_pressed)
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	joy_overlay.draw.connect(_on_joy_draw)
	mute_icon.draw.connect(_on_draw_mute_icon)
	restart_icon.draw.connect(_on_draw_restart_icon)
	menu_icon.draw.connect(_on_draw_menu_icon)

	_last_money = GameState.money
	cash_label.text = str(GameState.money)
	refresh_mute_icon()

func set_hud_visible(show_hud: bool, instant: bool = false) -> void:
	_hud_active = show_hud
	if not show_hud and _dragging:
		_dragging = false
		if _player != null:
			_player.set_virtual_joystick(Vector2.ZERO)
		joy_overlay.queue_redraw()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	if show_hud:
		visible = true
	if instant:
		hud_root.modulate.a = 1.0 if show_hud else 0.0
		visible = show_hud
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(hud_root, "modulate:a", 1.0 if show_hud else 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not show_hud:
		_fade_tween.tween_callback(func() -> void:
			if not _hud_active:
				visible = false
		)

func refresh_mute_icon() -> void:
	if is_instance_valid(mute_icon):
		mute_icon.queue_redraw()

func _on_game_reset() -> void:
	_last_money = GameState.money
	cash_label.text = str(GameState.money)

func _on_money_changed(new_amount: int) -> void:
	cash_label.text = str(new_amount)
	if new_amount > _last_money and visible and _hud_active:
		_pulse_cash_pill()
	_last_money = new_amount

func _pulse_cash_pill() -> void:
	if not is_instance_valid(top_left_pill):
		return
	top_left_pill.pivot_offset = top_left_pill.size * 0.5
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = top_left_pill.create_tween()
	_pulse_tween.tween_property(top_left_pill, "scale", Vector2(1.07, 1.07), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(top_left_pill, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_mute_pressed() -> void:
	SoundManager.toggle_muted()
	refresh_mute_icon()
	mute_toggled.emit()

func _on_draw_mute_icon() -> void:
	var c := mute_icon.size * 0.5
	var col := Color(0.95, 0.98, 1.0, 0.92)
	var cone := PackedVector2Array([
		c + Vector2(-8.0, -3.5),
		c + Vector2(-4.0, -3.5),
		c + Vector2(1.0, -7.5),
		c + Vector2(1.0, 7.5),
		c + Vector2(-4.0, 3.5),
		c + Vector2(-8.0, 3.5),
	])
	mute_icon.draw_colored_polygon(cone, col)
	if SoundManager.muted:
		mute_icon.draw_line(c + Vector2(3.5, -4.5), c + Vector2(9.0, 4.5), Color(1.0, 0.52, 0.52, 0.95), 2.0, true)
		mute_icon.draw_line(c + Vector2(9.0, -4.5), c + Vector2(3.5, 4.5), Color(1.0, 0.52, 0.52, 0.95), 2.0, true)
	else:
		mute_icon.draw_arc(c + Vector2(1.5, 0.0), 4.5, -0.75, 0.75, 10, col, 1.8, true)
		mute_icon.draw_arc(c + Vector2(1.5, 0.0), 8.0, -0.82, 0.82, 12, col, 1.8, true)

func _on_draw_restart_icon() -> void:
	var c := restart_icon.size * 0.5
	var col := Color(0.95, 0.98, 1.0, 0.92)
	var r := 7.5
	restart_icon.draw_arc(c, r, -PI * 0.72, PI * 0.85, 22, col, 2.0, true)
	var tip := c + Vector2(cos(-PI * 0.72), sin(-PI * 0.72)) * r
	var head := PackedVector2Array([
		tip + Vector2(-2.0, -2.5),
		tip + Vector2(4.2, -1.2),
		tip + Vector2(0.5, 3.8),
	])
	restart_icon.draw_colored_polygon(head, col)

func _on_draw_menu_icon() -> void:
	var c := menu_icon.size * 0.5
	var col := Color(0.95, 0.98, 1.0, 0.92)
	for offset_y in [-5.0, 0.0, 5.0]:
		menu_icon.draw_line(c + Vector2(-7.5, offset_y), c + Vector2(7.5, offset_y), col, 2.0, true)

func _unhandled_input(event: InputEvent) -> void:
	if not _hud_active:
		return

	# --- Temporary First-Person Mode ---
	if _player != null and _player.first_person_controls:
		if _dragging:
			_dragging = false
			_player.set_virtual_joystick(Vector2.ZERO)
			joy_overlay.queue_redraw()
		return
	# -----------------------------------

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_joy_origin = mb.position
				_joy_current = mb.position
				joy_overlay.queue_redraw()
			else:
				_dragging = false
				if _player != null:
					_player.set_virtual_joystick(Vector2.ZERO)
				joy_overlay.queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_joy_current = mm.position
		var delta := _joy_current - _joy_origin
		if delta.length() > JOY_RADIUS:
			delta = delta.normalized() * JOY_RADIUS
			_joy_current = _joy_origin + delta
		if _player != null:
			_player.set_virtual_joystick(delta / JOY_RADIUS)
		joy_overlay.queue_redraw()

func _on_joy_draw() -> void:
	if not _dragging:
		return
	joy_overlay.draw_circle(_joy_origin, JOY_RADIUS, Color(1.0, 1.0, 1.0, 0.09))
	joy_overlay.draw_arc(_joy_origin, JOY_RADIUS, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.28), 1.8, true)
	joy_overlay.draw_circle(_joy_current, 20.0, Color(1.0, 1.0, 1.0, 0.34))
