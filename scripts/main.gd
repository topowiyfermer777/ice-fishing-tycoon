extends Node3D
class_name MainGame

const WORKER_SCENE := preload("res://scenes/entities/worker_kenny.tscn")

@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudController = $HUD
@onready var main_menu: MainMenu = $MainMenu
@onready var _vfx: VfxManager = $VfxManager
@onready var _river: RiverBuilder = $River
@onready var _camp: CampBuilder = $Camp
@onready var _cash_zone: CashZone = $CashZone
@onready var _customer_system: CustomerQueueSystem = $CustomerQueueSystem
@onready var _chef_station: ChefStation = $ChefStation
@onready var _conveyor_system: ConveyorSystem = $ConveyorSystem
@onready var _river_ice: RiverIceSystem = $RiverIceSystem
@onready var _hero: PlayerController = $Hero
@onready var _workers_container: Node3D = $Workers
@onready var _upgrade_pads: Node3D = $UpgradePads

@onready var _dam_pad: UpgradePad = $UpgradePads/LogDamPad
@onready var _conveyor_pad: UpgradePad = $UpgradePads/ConveyorPad
@onready var _worker_pad: UpgradePad = $UpgradePads/AddWorkerPad

var _cheat_menu: CheatMenu
var _cheat_one_hit: bool = false
var _cheat_fast_speed: bool = false
var _in_menu: bool = true
var _has_started: bool = false
var _menu_easter_egg_claimed: bool = false

func _ready() -> void:
	_river.setup(_vfx)
	_customer_system.setup(_vfx, _cash_zone)
	_conveyor_system.setup(_chef_station, _customer_system, _vfx)
	_chef_station.setup(_vfx, _conveyor_system, _camp)
	_river_ice.setup(_vfx, _chef_station, _river, _conveyor_system)
	_river_ice.set_actors(_hero, _workers_container)

	_hero.setup(_river_ice, _chef_station, _customer_system, _cash_zone, _camp, _vfx)
	_hero.reset_position()
	camera_rig.follow_target = _hero

	_dam_pad.bind_player(_hero)
	_dam_pad.purchased.connect(_on_dam_purchased)

	_conveyor_pad.bind_player(_hero)
	_conveyor_pad.purchased.connect(_on_conveyor_purchased)

	_worker_pad.bind_player(_hero)
	_worker_pad.purchased.connect(_on_worker_purchased)

	hud.set_player(_hero)
	hud.restart_requested.connect(_on_restart_requested)
	hud.menu_requested.connect(_open_menu)
	hud.mute_toggled.connect(func() -> void: main_menu.refresh_sound_label())
	GameState.game_reset.connect(_on_game_reset)

	main_menu.play_pressed.connect(_on_menu_play)
	main_menu.restart_pressed.connect(_on_menu_restart)
	main_menu.sound_toggled.connect(func() -> void: hud.refresh_mute_icon())
	main_menu.quit_pressed.connect(_on_menu_quit)
	main_menu.easter_egg_triggered.connect(_on_menu_easter_egg)
	_river_ice.menu_block_broken.connect(main_menu.increment_ice_broken)

	_in_menu = true
	_has_started = false
	_river_ice.set_menu_mode(true)
	_set_gameplay_paused(true)
	camera_rig.set_menu_mode(true, true)
	hud.set_hud_visible(false, true)
	main_menu.show_menu(false, true)

	_cheat_menu = CheatMenu.new()
	_cheat_menu.name = "CheatMenu"
	add_child(_cheat_menu)
	_cheat_menu.setup(self)

func _on_dam_purchased(_pad: UpgradePad) -> void:
	_dam_pad.set_active(false)
	GameState.mark_dam_built()
	_vfx.spawn_build_burst(_dam_pad.global_position)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if GameState.dam_built and not GameState.conveyor_built and is_instance_valid(_conveyor_pad):
			_conveyor_pad.set_active(true)
	)

func _on_conveyor_purchased(_pad: UpgradePad) -> void:
	_conveyor_pad.set_active(false)
	GameState.mark_conveyor_built()
	_vfx.spawn_build_burst(_conveyor_pad.global_position)

func _on_worker_purchased(_pad: UpgradePad) -> void:
	var idx := GameState.add_worker()
	if idx >= 0:
		var worker := WORKER_SCENE.instantiate() as WorkerAI
		worker.setup(idx, _river_ice, _vfx)
		_workers_container.add_child(worker)
		var spawn_base := _camp.get_worker_spawn_pos() if _camp != null else Vector3(0.45, 0.0, -1.35)
		worker.global_position = spawn_base + Vector3(0.0, 0.0, float(idx) * 0.45)
		_vfx.spawn_customer_puff(worker.global_position)

	var next_cost := GameState.get_next_worker_cost()
	if next_cost > 0:
		_worker_pad.set_cost(next_cost)
		_worker_pad.set_active(true)
	else:
		_worker_pad.set_active(false)

func _on_restart_requested() -> void:
	GameState.reset_state()

func _on_game_reset() -> void:
	_cheat_one_hit = false
	_cheat_fast_speed = false
	_menu_easter_egg_claimed = false
	if is_instance_valid(main_menu):
		main_menu.reset_easter_egg()
	Engine.time_scale = 1.0
	for w in _workers_container.get_children():
		w.queue_free()
	if is_instance_valid(_hero):
		_hero.mine_damage = 1
		_hero.move_speed = 4.15
		_hero.carry_speed = 3.85
		_hero.reset_position()
	if is_instance_valid(_dam_pad):
		_dam_pad.set_cost(GameState.LOG_DAM_COST)
		_dam_pad.set_active(true)
	if is_instance_valid(_conveyor_pad):
		_conveyor_pad.set_cost(GameState.CONVEYOR_COST)
		_conveyor_pad.set_active(false)
	if is_instance_valid(_worker_pad):
		_worker_pad.set_cost(GameState.WORKER_COSTS[0])
		_worker_pad.set_active(true)

func _set_gameplay_paused(paused: bool) -> void:
	var mode := Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	for sys in [_hero, _workers_container, _chef_station, _conveyor_system, _customer_system, _cash_zone, _upgrade_pads]:
		if is_instance_valid(sys):
			(sys as Node).process_mode = mode
	if is_instance_valid(_hero):
		_hero.input_enabled = not paused
		_hero.visible = not paused
	if is_instance_valid(_workers_container):
		_workers_container.visible = not paused

func _on_menu_play() -> void:
	_in_menu = false
	_has_started = true
	_river_ice.set_menu_mode(false)
	_set_gameplay_paused(false)
	main_menu.hide_menu()
	camera_rig.set_menu_mode(false)
	hud.set_hud_visible(true)

func _open_menu() -> void:
	if _in_menu:
		return
	_in_menu = true
	_river_ice.set_menu_mode(true)
	_set_gameplay_paused(true)
	camera_rig.set_menu_mode(true)
	hud.set_hud_visible(false)
	main_menu.show_menu(_has_started)

func _on_menu_restart() -> void:
	_set_gameplay_paused(false)
	GameState.reset_state()
	_on_menu_play()

func _on_menu_quit() -> void:
	get_tree().quit()

func _on_menu_easter_egg(_first_time: bool) -> void:
	if is_instance_valid(_river_ice):
		_river_ice.trigger_menu_easter_egg()

func _unhandled_input(event: InputEvent) -> void:
	if _in_menu and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var origin := camera_rig.project_ray_origin(mb.position)
			var dir := camera_rig.project_ray_normal(mb.position)
			var hit_block := _river_ice.find_block_along_ray(origin, dir)
			if hit_block != null:
				hit_block.take_hit(1, origin)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
			if _in_menu and _has_started:
				_on_menu_play()
				get_viewport().set_input_as_handled()
				return
			elif not _in_menu:
				_open_menu()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("restart_game") and not _in_menu:
		GameState.reset_state()

func cheat_add_money(amount: int) -> void:
	GameState.add_money(amount)

func cheat_clear_money() -> void:
	GameState.money = 0
	GameState.money_changed.emit(0)

func cheat_build_dam() -> void:
	if not GameState.dam_built and is_instance_valid(_dam_pad):
		_on_dam_purchased(_dam_pad)

func cheat_build_conveyor() -> void:
	if not GameState.dam_built:
		cheat_build_dam()
	if not GameState.conveyor_built and is_instance_valid(_conveyor_pad):
		_on_conveyor_purchased(_conveyor_pad)

func cheat_hire_worker() -> void:
	if GameState.workers_hired < GameState.MAX_WORKERS and is_instance_valid(_worker_pad):
		_on_worker_purchased(_worker_pad)

func cheat_unlock_all() -> void:
	cheat_build_dam()
	cheat_build_conveyor()
	while GameState.workers_hired < GameState.MAX_WORKERS:
		cheat_hire_worker()

func cheat_toggle_one_hit() -> bool:
	_cheat_one_hit = not _cheat_one_hit
	if is_instance_valid(_hero):
		_hero.mine_damage = 99 if _cheat_one_hit else 1
	return _cheat_one_hit

func cheat_toggle_speed() -> bool:
	_cheat_fast_speed = not _cheat_fast_speed
	if is_instance_valid(_hero):
		_hero.move_speed = 8.3 if _cheat_fast_speed else 4.15
		_hero.carry_speed = 7.7 if _cheat_fast_speed else 3.85
	return _cheat_fast_speed

func cheat_spawn_giant_ice() -> void:
	if is_instance_valid(_river_ice):
		_river_ice.spawn_cheat_block(true)

func cheat_clear_carry() -> void:
	if is_instance_valid(_hero) and _hero.stack_carry != null:
		_hero.stack_carry.clear_all()

func cheat_toggle_camera() -> bool:
	if is_instance_valid(camera_rig):
		camera_rig.camera_mode = CameraRig.CameraMode.FIRST_PERSON if camera_rig.camera_mode == CameraRig.CameraMode.ISOMETRIC else CameraRig.CameraMode.ISOMETRIC
	return is_first_person_camera()

func is_first_person_camera() -> bool:
	return is_instance_valid(camera_rig) and camera_rig.camera_mode == CameraRig.CameraMode.FIRST_PERSON
