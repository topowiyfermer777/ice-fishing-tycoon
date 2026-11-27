extends CanvasLayer
class_name CheatMenu

const TIME_SCALES: Array[float] = [1.0, 2.0, 3.0]

var _game: MainGame
var _panel: PanelContainer
var _one_hit_btn: Button
var _speed_btn: Button
var _time_btn: Button
var _camera_btn: Button

var _one_hit_on: bool = false
var _fast_speed_on: bool = false
var _time_idx: int = 0

func setup(game: MainGame) -> void:
	_game = game
	_refresh_toggle_texts()

func _ready() -> void:
	layer = 20
	_build_ui()
	_panel.visible = false
	GameState.game_reset.connect(_on_game_reset)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.physical_keycode == KEY_F1 or key.physical_keycode == KEY_QUOTELEFT):
			_set_menu_open(not _panel.visible)
			get_viewport().set_input_as_handled()

func _set_menu_open(open: bool) -> void:
	_panel.visible = open
	if open:
		_refresh_toggle_texts()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if _game != null and _game.is_first_person_camera():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "CheatPanel"
	_panel.offset_left = 22.0
	_panel.offset_top = 118.0
	_panel.offset_right = 312.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.19, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.76, 0.36, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "Чит-меню [F1]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.45, 0.96, 0.52, 1.0))
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 26)
	close_btn.pressed.connect(func() -> void: _set_menu_open(false))
	header.add_child(close_btn)

	_add_section_label(root, "Деньги")
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 6)
	root.add_child(money_row)
	_add_btn(money_row, "+$100", func() -> void:
		if _game != null:
			_game.cheat_add_money(100)
	, true)
	_add_btn(money_row, "+$1000", func() -> void:
		if _game != null:
			_game.cheat_add_money(1000)
	, true)
	_add_btn(money_row, "$0", func() -> void:
		if _game != null:
			_game.cheat_clear_money()
	, false)

	_add_section_label(root, "База")
	var base_grid := GridContainer.new()
	base_grid.columns = 2
	base_grid.add_theme_constant_override("h_separation", 6)
	base_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(base_grid)
	_add_btn(base_grid, "Дамба", func() -> void:
		if _game != null:
			_game.cheat_build_dam()
	, true)
	_add_btn(base_grid, "Конвейер", func() -> void:
		if _game != null:
			_game.cheat_build_conveyor()
	, true)
	_add_btn(base_grid, "+1 Рабочий", func() -> void:
		if _game != null:
			_game.cheat_hire_worker()
	, true)
	_add_btn(base_grid, "Открыть всё", func() -> void:
		if _game != null:
			_game.cheat_unlock_all()
	, true)

	_add_section_label(root, "Геймплей")
	_one_hit_btn = _add_btn(root, "", func() -> void:
		if _game != null:
			_one_hit_on = _game.cheat_toggle_one_hit()
			_refresh_toggle_texts()
	)
	_speed_btn = _add_btn(root, "", func() -> void:
		if _game != null:
			_fast_speed_on = _game.cheat_toggle_speed()
			_refresh_toggle_texts()
	)
	_time_btn = _add_btn(root, "", func() -> void:
		_time_idx = (_time_idx + 1) % TIME_SCALES.size()
		Engine.time_scale = TIME_SCALES[_time_idx]
		_refresh_toggle_texts()
	)
	_add_btn(root, "Заспавнить гигантский лёд", func() -> void:
		if _game != null:
			_game.cheat_spawn_giant_ice()
	)
	_add_btn(root, "Очистить руки героя", func() -> void:
		if _game != null:
			_game.cheat_clear_carry()
	)
	_camera_btn = _add_btn(root, "", func() -> void:
		if _game != null:
			_game.cheat_toggle_camera()
			# Keep cursor visible while the Cheat Menu remains open
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_refresh_toggle_texts()
	)
	_add_btn(root, "Перезапустить игру", func() -> void:
		GameState.reset_state()
	)

func _add_section_label(parent: Control, caption: String) -> void:
	var lbl := Label.new()
	lbl.text = caption
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 0.95, 0.9))
	parent.add_child(lbl)

func _add_btn(parent: Control, caption: String, cb: Callable, expand: bool = false) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 13)
	if expand:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _on_game_reset() -> void:
	_one_hit_on = false
	_fast_speed_on = false
	_time_idx = 0
	Engine.time_scale = 1.0
	_refresh_toggle_texts()

func _refresh_toggle_texts() -> void:
	if _one_hit_btn != null:
		_one_hit_btn.text = "Ваншот льда: %s" % ("ВКЛ" if _one_hit_on else "ВЫКЛ")
	if _speed_btn != null:
		_speed_btn.text = "Скорость ×2: %s" % ("ВКЛ" if _fast_speed_on else "ВЫКЛ")
	if _time_btn != null:
		_time_btn.text = "Время: %.1fx" % TIME_SCALES[_time_idx]
	if _camera_btn != null:
		var is_fp := _game != null and _game.is_first_person_camera()
		_camera_btn.text = "Камера: %s" % ("1-е лицо" if is_fp else "Изометрия")
