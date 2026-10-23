extends Node2D
const INK := Color("292932")
const MUTED := Color("73737f")
const PAPER := Color("eeeef2")
var settings := NinjaSettings.new()
var campaign: Array = []
var sim := NinjaSimulation.new()
var world: Node2D
var map_view: NinjaMapView
var zoom_control: SpinBox
var sound: Node
var ui := Control.new()
var hud := Control.new()
var menu := Control.new()
var overlay := Control.new()
var time_label: Label
var status_label: Label
var fps_label: Label
var title_label: Label
var state := "menu"
var settings_return := "menu"
var level_index := 0
var font := SystemFont.new()
var capture_path := ""
var capture_screen := "play"
var capture_frames := 0
var capture_ready := true
var capture_viewport: Viewport
var window_mode := NinjaWindowMode.new()
var fullscreen_check: CheckButton
var settings_tab := "general"
var binding_action := ""
var binding_slot := -1
var binding_buttons: Dictionary = {}
var binding_notice: Label
var skins: NinjaSkins
var skin_screen: Control

func _ready() -> void:
	DisplayServer.window_set_title("N VLink · 0.6.1")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-screen="):
			capture_screen = argument.trim_prefix("--capture-screen=")
	if not capture_path.is_empty():
		settings = NinjaSettings.new(true)
		settings.path = settings.path.get_base_dir().path_join("capture_settings.json")
	if skins == null:
		var skin_base := settings.path.get_base_dir()
		if settings.path.get_file() != "settings.json": skin_base = skin_base.path_join(settings.path.get_file().get_basename())
		skins = NinjaSkins.new(skin_base)
	if not skins.appearance.get("v06_examples",false): skins.install_v06_demo(true)
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "CheckButton", INK)
	theme.set_color("font_pressed_color", "CheckButton", INK)
	theme.set_color("font_hover_color", "CheckButton", INK)
	theme.set_color("font_hover_pressed_color", "CheckButton", INK)
	theme.set_color("font_focus_color", "CheckButton", INK)
	theme.set_color("font_color", "CheckBox", INK)
	ui.theme = theme
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.apply()
	NinjaBindings.install(settings.bindings)
	window_mode.set_fullscreen(settings.fullscreen)
	get_window().focus_exited.connect(on_focus_lost)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	if not data is Dictionary or data.get("levels", []).size() != 500:
		push_error("Campaign data is missing or incomplete")
		get_tree().quit(1)
		return
	campaign = data.levels
	world = Node2D.new()
	world.set_script(preload("res://view/world_view.gd"))
	world.skins = skins
	world.show_collisions = settings.show_collisions
	map_view = NinjaMapView.new()
	map_view.position = Vector2(116, 112)
	map_view.world = world
	map_view.set_view_policy({"zoom": settings.map_zoom})
	add_child(map_view)
	world.hide()
	sound = Node.new()
	sound.set_script(preload("res://view/sound.gd"))
	add_child(sound)
	sound.volume = settings.volume
	add_child(ui)
	ui.add_child(hud)
	ui.add_child(menu)
	ui.add_child(overlay)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_hud()
	show_menu()
	if not capture_path.is_empty():
		Engine.max_fps = 60
		skins.reset_all()
		if capture_screen == "play":
			start_episode(0)
		elif capture_screen == "skins":
			skins.install_demo()
			skins.install_v06_demo()
			show_skins()
			skin_screen.slot="drone_scout"
			skin_screen.refresh()
			skin_screen.state_picker.select(1)
			skin_screen.refresh_selection()
		elif capture_screen in ["presets", "fetch"]:
			show_skins()
			if capture_screen == "presets":
				skin_screen.open_presets()
				var presets: NinjaPresetScreen=skin_screen.get_child(skin_screen.get_child_count()-1)
				if presets.library.size()<3: get_tree().quit(1); return
				for i in range(presets.library.size()):
					if presets.library[i].name=="白金·临光": presets.selector.select(i)
				presets.load_selected()
				if skins.preset_name!="白金·临光" or not skins.clips.has("drone_scout@move"): get_tree().quit(1); return
				capture_viewport=presets
				print("EXPORTED_PRESETS_OK")
			else:
				skin_screen.open_prts()
				var fetch: NinjaPRTSScreen=skin_screen.get_child(skin_screen.get_child_count()-1)
				capture_ready=false; fetch.character.text="临光"
				await fetch.start_download()
				if not fetch.last_result.ok or fetch.last_result.downloads.size()!=9: get_tree().quit(1); return
				capture_viewport=fetch; capture_ready=true
				print("EXPORTED_FETCH_OK: 9 assets")
		elif capture_screen == "rig":
			skins.install_demo()
			show_skins()
			skin_screen.select_category("player")
			skin_screen.slot = "player_left_calf"
			skin_screen.refresh()
			skin_screen.edit_layout()
		elif capture_screen == "collisions":
			skins.install_demo()
			settings.show_collisions = true
			start_episode(50)
		elif capture_screen == "settings":
			show_settings("menu")
		elif capture_screen == "bindings":
			show_settings("menu", "bindings")
		elif capture_screen in ["death", "explosive"]:
			skins.install_demo()
			start_episode(50)
			sim.ninja.reset(Vector2(300, 200))
			sim.ninja.kill("爆炸" if capture_screen == "explosive" else "无人机", capture_screen == "explosive", Vector2(298, 205), Vector2(60, -50), NinjaBody.DeathKind.ELECTRIC)
			_physics_process(NinjaSimulation.DT)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1024, 768), Color("e4e4e9"))
	draw_line(Vector2(56, 727), Vector2(968, 727), Color("bdbdc7"), 1)
	if state == "menu":
		for i in range(7):
			draw_line(Vector2(54 + i * 12, 55), Vector2(54 + i * 12, 65), MUTED, 1)

func build_hud() -> void:
	label(hud, "N / VLINK", Vector2(116, 27), Vector2(200, 32), 24)
	label(hud, "地图", Vector2(334, 30), Vector2(50, 28), 14)
	var zoom := SpinBox.new()
	zoom_control = zoom
	zoom.name = "MapZoom"
	zoom.position = Vector2(384, 26)
	zoom.size = Vector2(94, 34)
	zoom.min_value = 1
	zoom.max_value = 4
	zoom.step = 0.25
	zoom.suffix = "×"
	zoom.value = settings.map_zoom
	zoom.value_changed.connect(func(value: float): settings.map_zoom = value; settings.save(); map_view.set_view_policy({"zoom": value}))
	hud.add_child(zoom)
	button(hud, "全图", Rect2(487, 28, 62, 31), func(): zoom.value = 1)
	button(hud, "跟随", Rect2(557, 28, 62, 31), func(): map_view.reset_follow(); zoom.value = maxf(1.5, zoom.value))
	button(hud, "设置", Rect2(760, 28, 70, 31), func(): show_settings("paused"))
	button(hud, "暂停", Rect2(838, 28, 70, 31), show_pause)
	title_label = label(hud, "", Vector2(116, 74), Vector2(545, 28), 17)
	time_label = label(hud, "", Vector2(680, 70), Vector2(228, 35), 25)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label = label(hud, "", Vector2(116, 729), Vector2(640, 24), 12, MUTED)
	fps_label = label(hud, "", Vector2(740, 729), Vector2(168, 24), 12, MUTED)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func show_menu() -> void:
	if is_instance_valid(skin_screen) and skin_screen.busy: return
	state = "menu"
	world.hide()
	hud.hide()
	clear_children(overlay)
	clear_children(menu)
	menu.show()
	label(menu, "N", Vector2(48, 76), Vector2(260, 180), 142)
	label(menu, "V L I N K", Vector2(60, 251), Vector2(330, 40), 31)
	label(menu, "再一次，跃过不可能。", Vector2(61, 310), Vector2(340, 36), 21)
	label(menu, "N 1.4 · Godot 重构原型 0.5.2", Vector2(62, 357), Vector2(335, 30), 15, MUTED)
	label(menu, "100 组关卡 / 500 张原版地图", Vector2(62, 387), Vector2(335, 30), 15, MUTED)
	button(menu, "开始  %02d" % settings.last_episode, Rect2(62, 450, 295, 48), func(): start_episode(settings.last_episode), true)
	button(menu, "设置", Rect2(62, 510, 141, 40), func(): show_settings("menu"))
	button(menu, "退出", Rect2(215, 510, 142, 40), func(): get_tree().quit())
	button(menu, "自定义贴图", Rect2(62, 566, 295, 42), show_skins)
	label(menu, "选择关卡组", Vector2(446, 97), Vector2(400, 35), 25)
	label(menu, "每组 5 关，共用倒计时；金块 +2 秒。", Vector2(447, 145), Vector2(500, 30), 14, MUTED)
	for episode in range(100):
		var col := episode % 10
		var row := episode / 10
		var completed := settings.completed.has(str(episode))
		var b := button(menu, "%02d" % episode, Rect2(447 + col * 49, 202 + row * 44, 41, 35), func(): start_episode(episode), completed)
		var first: Dictionary = campaign[episode * 5]
		b.tooltip_text = "%02d · %s%s" % [episode, first.title, " · 已完成" if completed else ""]
	label(menu, "关卡已全部开放，按自己的节奏来。", Vector2(447, 665), Vector2(490, 30), 14, MUTED)
	label(menu, "独立重构原型 · 原作与关卡 © Metanet Software", Vector2(62, 732), Vector2(830, 25), 12, MUTED)
	queue_redraw()

func start_episode(episode: int) -> void:
	settings.last_episode = episode
	settings.save()
	level_index = episode * 5
	load_level(90.0)

func load_level(seconds: float) -> void:
	NinjaBindings.release_actions()
	sim.acceleration = settings.acceleration
	sim.ninja.max_speed = settings.max_speed
	world.show_collisions = settings.show_collisions
	sim.load_level(campaign[level_index], seconds)
	world.load_simulation(sim)
	map_view.camera.initialized = false
	world.show()
	world.paused = false
	hud.show()
	menu.hide()
	clear_children(overlay)
	state = "playing"
	title_label.text = "%s   /   %s" % [sim.level.id, sim.level.title]
	queue_redraw()

func retry() -> void:
	if not campaign.is_empty() and state in ["playing", "paused", "dead", "won"]:
		load_level(sim.start_time)

func suicide() -> void:
	if state not in ["playing", "paused"] or not sim.ninja.alive: return
	NinjaBindings.release_actions()
	sim.suicide()
	sound.play_event("death")
	state = "dead"
	show_result(false)

func next_level() -> void:
	if int(sim.level.slot) == 4:
		settings.completed[str(sim.level.episode)] = true
		var best: float = float(settings.best_times.get(str(sim.level.episode), 0))
		settings.best_times[str(sim.level.episode)] = maxf(best, sim.time_left)
		settings.save()
		show_menu()
	else:
		level_index += 1
		load_level(sim.time_left)

func _physics_process(_delta: float) -> void:
	if state == "dead":
		sim.step(0)
		return
	if state != "playing":
		return
	sim.step(NinjaInputFrame.sample())
	for event in sim.events:
		sound.play_event(event)
	if not sim.ninja.alive:
		state = "dead"
		show_result(false)
	elif sim.won:
		state = "won"
		world.paused = true
		show_result(true)

func _process(_delta: float) -> void:
	if hud.visible:
		if not zoom_control.get_line_edit().has_focus(): zoom_control.set_value_no_signal(map_view.camera.zoom)
		time_label.text = "%06.2f  s" % sim.time_left
		status_label.text = "金块 %d / %d      %s 自杀 · %s 暂停      加速度 %.2f×" % [sim.gold, sim.total_gold, key_hint("retry"), key_hint("pause"), settings.acceleration]
		fps_label.text = "%d FPS  /  %s" % [Engine.get_frames_per_second(), "∞" if settings.max_fps == 0 else str(settings.max_fps)]
	if not capture_path.is_empty() and capture_ready:
		capture_frames += 1
		if capture_frames == 45:
			await RenderingServer.frame_post_draw
			var image := (capture_viewport if is_instance_valid(capture_viewport) else get_viewport()).get_texture().get_image()
			var result := image.save_png(capture_path)
			print("CAPTURE_RESULT=", result, " PATH=", capture_path)
			get_tree().quit(result)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not binding_action.is_empty():
		capture_binding(event)
		get_viewport().set_input_as_handled()
		return
	# Before GUI handling: fullscreen works even when a text field has focus.
	if event.is_action_pressed("n_fullscreen"):
		set_fullscreen(not window_mode.is_fullscreen())
		get_viewport().set_input_as_handled()
		return
	if state == "playing": NinjaInputFrame.observe(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.is_action_pressed("n_pause"):
		if state == "skins":
			if is_instance_valid(skin_screen) and not skin_screen.dialog.visible: show_menu()
		elif state == "settings": close_settings()
		elif state == "paused": resume()
		elif state == "playing": show_pause()
		elif state in ["dead", "won"]: show_menu()
	elif event.is_action_pressed("n_retry"):
		suicide()
	elif event.is_action_pressed("n_confirm"):
		if state == "won": next_level()
		elif state == "dead": retry()

func set_fullscreen(enabled: bool) -> void:
	window_mode.set_fullscreen(enabled)
	settings.fullscreen = enabled
	settings.save()
	if is_instance_valid(fullscreen_check): fullscreen_check.set_pressed_no_signal(enabled)

func on_focus_lost() -> void:
	NinjaBindings.release_actions()
	if state == "playing": show_pause()

func key_hint(action: String) -> String:
	return NinjaBindings.primary_name(settings.bindings, action)

func show_pause() -> void:
	if state != "playing":
		return
	state = "paused"
	world.paused = true
	var panel := modal("暂停", "喘口气，下一次跳跃还在等你。", 340)
	button(panel, "继续", Rect2(36, 135, 376, 43), resume, true)
	button(panel, "设置", Rect2(36, 191, 183, 40), func(): show_settings("paused"))
	button(panel, "关卡选择", Rect2(229, 191, 183, 40), show_menu)
	label(panel, "%s 继续 · %s 自杀" % [key_hint("pause"), key_hint("retry")], Vector2(36, 274), Vector2(376, 25), 13, MUTED)

func resume() -> void:
	NinjaBindings.release_actions()
	sim.ninja.clear_jump_assist()
	clear_children(overlay)
	state = "playing"
	world.paused = false

func show_result(success: bool) -> void:
	if not success:
		show_death_banner()
		return
	var heading := "关卡组完成" if success and int(sim.level.slot) == 4 else ("出口已抵达" if success else "再来一次")
	var subtitle := "剩余 %.2f 秒 · 收集 %d / %d 金块" % [sim.time_left, sim.gold, sim.total_gold] if success else sim.ninja.death_reason
	var panel := modal(heading, subtitle, 276)
	button(panel, "返回选择" if success and int(sim.level.slot) == 4 else ("下一关  " + key_hint("confirm") if success else "重试  " + key_hint("confirm")), Rect2(36, 139, 376, 43), next_level if success else retry, true)
	button(panel, "关卡选择", Rect2(36, 197, 376, 34), show_menu)
	if success and int(sim.level.slot) == 4:
		settings.completed[str(sim.level.episode)] = true
		settings.best_times[str(sim.level.episode)] = maxf(float(settings.best_times.get(str(sim.level.episode), 0)), sim.time_left)
		settings.save()

func show_death_banner() -> void:
	clear_children(overlay)
	world.paused = false
	var panel := Panel.new()
	panel.name = "DeathBanner"
	panel.position = Vector2(116, 65)
	panel.size = Vector2(792, 40)
	panel.add_theme_stylebox_override("panel", box(Color("eeeef2"), 4))
	overlay.add_child(panel)
	label(panel, "死亡 · " + sim.ninja.death_reason, Vector2(12, 5), Vector2(400, 30), 17, Color("b44242"))
	button(panel, "重试  " + key_hint("confirm"), Rect2(505, 4, 145, 32), retry, true)
	button(panel, "关卡选择", Rect2(660, 4, 120, 32), show_menu)

func show_settings(return_to: String, tab: String = "general") -> void:
	if state == "playing":
		return_to = "paused"
	elif state in ["dead", "won"]:
		return_to = state
	settings_return = return_to
	state = "settings"
	settings_tab = tab
	binding_action = ""
	binding_slot = -1
	binding_buttons.clear()
	world.paused = true
	clear_children(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.13, 0.13, 0.17, 0.55)
	veil.size = Vector2(1024, 768)
	overlay.add_child(veil)
	var panel := Panel.new()
	panel.position = Vector2(172, 32)
	panel.size = Vector2(680, 704)
	panel.add_theme_stylebox_override("panel", box(PAPER, 12))
	overlay.add_child(panel)
	label(panel, "设置", Vector2(36, 26), Vector2(480, 42), 28)
	button(panel, "画面与手感", Rect2(36, 80, 298, 36), func(): show_settings(settings_return, "general"), tab == "general")
	button(panel, "按键绑定", Rect2(346, 80, 298, 36), func(): show_settings(settings_return, "bindings"), tab == "bindings")
	var body := Control.new()
	body.position = Vector2(42, 40)
	panel.add_child(body)
	if tab == "bindings": build_binding_settings(body)
	else: build_general_settings(body)
	button(panel, "恢复默认", Rect2(36, 627, 170, 42), func():
		if settings_tab == "bindings":
			settings.bindings = NinjaBindings.DEFAULTS.duplicate(true)
			NinjaBindings.install(settings.bindings)
		else:
			settings.max_fps = 0
			settings.vsync = false
			settings.acceleration = 1
			settings.max_speed = NinjaBody.SPEED
			settings.show_collisions = false
			settings.volume = 0.45
		# General reset intentionally leaves the window mode and size alone.
		apply_settings()
		show_settings(settings_return, settings_tab))
	button(panel, "完成", Rect2(474, 627, 170, 42), close_settings, true)

func build_general_settings(panel: Control) -> void:
	label(panel, "画面", Vector2(36, 91), Vector2(480, 25), 15, MUTED)
	var unlimited := CheckButton.new()
	unlimited.text = "无限帧率"
	unlimited.position = Vector2(32, 124)
	unlimited.size = Vector2(258, 36)
	unlimited.button_pressed = settings.max_fps == 0
	panel.add_child(unlimited)
	label(panel, "最高帧率", Vector2(316, 128), Vector2(100, 30), 15)
	var fps := SpinBox.new()
	fps.name = "MaxFPS"
	fps.position = Vector2(427, 124)
	fps.size = Vector2(130, 38)
	fps.min_value = 1
	fps.max_value = 1000
	fps.step = 1
	fps.value = settings.max_fps if settings.max_fps > 0 else 144
	fps.editable = settings.max_fps != 0
	panel.add_child(fps)
	unlimited.toggled.connect(func(on: bool):
		fps.editable = not on
		settings.max_fps = 0 if on else int(fps.value)
		apply_settings())
	fps.value_changed.connect(func(value: float):
		if not unlimited.button_pressed:
			settings.max_fps = int(value)
			apply_settings())
	var vsync := CheckButton.new()
	vsync.text = "垂直同步"
	vsync.position = Vector2(32, 176)
	vsync.button_pressed = settings.vsync
	panel.add_child(vsync)
	vsync.toggled.connect(func(on: bool): settings.vsync = on; apply_settings())
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "全屏"
	fullscreen_check.position = Vector2(312, 176)
	fullscreen_check.button_pressed = settings.fullscreen
	panel.add_child(fullscreen_check)
	fullscreen_check.toggled.connect(set_fullscreen)
	var hitboxes := CheckButton.new()
	hitboxes.text = "显示碰撞箱"
	hitboxes.position = Vector2(32, 216)
	hitboxes.button_pressed = settings.show_collisions
	panel.add_child(hitboxes)
	hitboxes.toggled.connect(func(on: bool): settings.show_collisions = on; apply_settings())
	label(panel, "青色：实体边界　红色：危险碰撞　黄色：触发范围", Vector2(36, 256), Vector2(524, 24), 12, MUTED)
	label(panel, "操作手感", Vector2(36, 290), Vector2(480, 25), 15, MUTED)
	label(panel, "最大移速（像素/秒）", Vector2(36, 328), Vector2(310, 30), 16)
	var max_speed := SpinBox.new()
	max_speed.name = "MaxSpeed"
	max_speed.position = Vector2(427, 322)
	max_speed.size = Vector2(130, 38)
	max_speed.min_value = 60
	max_speed.max_value = 400
	max_speed.step = 1
	max_speed.value = settings.max_speed
	panel.add_child(max_speed)
	max_speed.value_changed.connect(func(value: float): settings.max_speed = value; apply_settings())
	label(panel, "加速度倍率", Vector2(36, 374), Vector2(250, 30), 17)
	var value_label := label(panel, "%.2f×" % settings.acceleration, Vector2(465, 374), Vector2(92, 30), 19)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var acceleration := HSlider.new()
	acceleration.position = Vector2(36, 411)
	acceleration.size = Vector2(520, 22)
	acceleration.min_value = 0.25
	acceleration.max_value = 4.0
	acceleration.step = 0.05
	acceleration.value = settings.acceleration
	panel.add_child(acceleration)
	acceleration.value_changed.connect(func(value: float):
		settings.acceleration = value
		value_label.text = "%.2f×" % value
		apply_settings())
	label(panel, "默认移速 216，比地面守卫快约 5%。\n加速度只改变起步和转向，地面与空中上限一致。", Vector2(36, 445), Vector2(524, 48), 13, MUTED)
	label(panel, "音量", Vector2(36, 493), Vector2(80, 25), 15)
	var volume := HSlider.new()
	volume.position = Vector2(133, 498)
	volume.size = Vector2(423, 20)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = settings.volume
	panel.add_child(volume)
	volume.value_changed.connect(func(value: float): settings.volume = value; apply_settings())

func build_binding_settings(panel: Control) -> void:
	label(panel, "点击键位后按下新按键；每项最多绑定三个键。", Vector2(0, 94), Vector2(596, 28), 14, MUTED)
	for slot in range(3):
		label(panel, ["主键", "备用一", "备用二"][slot], Vector2(155 + slot * 146, 140), Vector2(125, 24), 13, MUTED)
	for row in range(NinjaBindings.ACTIONS.size()):
		var action: String = NinjaBindings.ACTIONS[row]
		var y := 179 + row * 48
		label(panel, NinjaBindings.LABELS[action], Vector2(0, y + 5), Vector2(150, 30), 15)
		for slot in range(3):
			var key := action + str(slot)
			var b := button(panel, NinjaBindings.key_name(int(settings.bindings[action][slot])), Rect2(155 + slot * 146, y, 103, 35), func(): begin_binding(action, slot))
			b.name = "Bind_" + action + "_" + str(slot)
			binding_buttons[key] = b
			var clear := button(panel, "×", Rect2(262 + slot * 146, y, 25, 35), func():
				settings.bindings[action][slot] = 0
				finish_binding()
				NinjaBindings.install(settings.bindings)
				settings.save())
			clear.tooltip_text = "清除此键位"
	binding_notice = label(panel, "键位自动保存。重复绑定会提示冲突。", Vector2(0, 528), Vector2(460, 45), 13, MUTED)
	button(panel, "取消绑定", Rect2(476, 527, 117, 35), finish_binding)

func begin_binding(action: String, slot: int) -> void:
	finish_binding()
	binding_action = action
	binding_slot = slot
	binding_buttons[action + str(slot)].text = "请按键…"
	binding_notice.text = "正在绑定「%s」。按下新按键，或点击取消绑定。" % NinjaBindings.LABELS[action]

func capture_binding(event: InputEventKey) -> void:
	var code := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if code == 0: return
	var used := NinjaBindings.conflict(settings.bindings, code, binding_action, binding_slot)
	if not used.is_empty():
		binding_notice.text = "此键已用于「%s」，请换一个键，或先清除原绑定。" % used
		return
	settings.bindings[binding_action][binding_slot] = code
	NinjaBindings.install(settings.bindings)
	settings.save()
	finish_binding()

func finish_binding() -> void:
	binding_action = ""
	binding_slot = -1
	for action in NinjaBindings.ACTIONS:
		for slot in range(3):
			var b = binding_buttons.get(action + str(slot))
			if is_instance_valid(b): b.text = NinjaBindings.key_name(int(settings.bindings[action][slot]))
	if is_instance_valid(binding_notice): binding_notice.text = "键位自动保存。重复绑定会提示冲突。"

func apply_settings() -> void:
	settings.apply()
	settings.save()
	sim.acceleration = settings.acceleration
	sim.ninja.max_speed = settings.max_speed
	world.show_collisions = settings.show_collisions
	sound.volume = settings.volume

func show_skins() -> void:
	state = "skins"
	menu.hide()
	world.hide()
	hud.hide()
	clear_children(overlay)
	skin_screen = Control.new()
	skin_screen.set_script(preload("res://view/skin_screen.gd"))
	skin_screen.host = self
	skin_screen.skins = skins
	overlay.add_child(skin_screen)
	queue_redraw()

func close_settings() -> void:
	finish_binding()
	if settings_return == "menu":
		show_menu()
	elif settings_return in ["dead", "won"]:
		state = settings_return
		show_result(state == "won")
	else:
		state = "playing"
		show_pause()

func modal(heading: String, subtitle: String, height: float) -> Panel:
	clear_children(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.14, 0.14, 0.17, 0.47)
	veil.size = Vector2(1024, 768)
	overlay.add_child(veil)
	var panel := Panel.new()
	panel.position = Vector2(288, (768 - height) / 2)
	panel.size = Vector2(448, height)
	panel.add_theme_stylebox_override("panel", box(PAPER, 10))
	overlay.add_child(panel)
	label(panel, heading, Vector2(36, 29), Vector2(376, 40), 28)
	label(panel, subtitle, Vector2(36, 86), Vector2(376, 30), 15, MUTED)
	return panel

func label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color = INK) -> Label:
	var item := Label.new()
	item.text = text
	item.position = at
	item.size = dimensions
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func button(parent: Node, text: String, bounds: Rect2, action: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.position = bounds.position
	item.size = bounds.size
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size", 15)
	item.add_theme_color_override("font_color", PAPER if primary else INK)
	item.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	item.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	item.add_theme_stylebox_override("normal", box(INK if primary else Color("d8d8e1"), 5))
	item.add_theme_stylebox_override("hover", box(Color("484854") if primary else Color("c7c7d2"), 5))
	item.add_theme_stylebox_override("pressed", box(Color("656576") if primary else Color("b7b7c5"), 5))
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
