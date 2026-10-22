extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func frames() -> void:
	for i in range(5): await process_frame

func find_text(parent: Node, text: String) -> Node:
	for child in parent.get_children():
		if child is Button and child.text == text: return child
		var nested := find_text(child, text)
		if nested != null: return nested
	return null

func find_class(parent: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		if child.is_class(type_name): result.append(child)
		result.append_array(find_class(child, type_name))
	return result

func press(code: int) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Window regression requires a real Windows display")
		quit(1)
		return
	var main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = ProjectSettings.globalize_path("res://.local/test_window_settings.json")
	main.settings.max_fps = 60
	root.add_child(main)
	await frames()
	DisplayServer.window_set_size(Vector2i(1200, 800))
	DisplayServer.window_set_position(Vector2i(100, 60))
	await frames()
	var original := DisplayServer.window_get_size()
	main.show_settings("menu")
	for control in find_class(main.overlay, "HSlider"):
		control.value += control.step
	for control in find_class(main.overlay, "SpinBox"): control.value = 144
	find_text(main.overlay, "无限帧率").button_pressed = false
	find_text(main.overlay, "垂直同步").button_pressed = true
	await frames()
	check(DisplayServer.window_get_size() == original, "Sliders, FPS and VSync preserve custom window size")
	find_text(main.overlay, "恢复默认").pressed.emit()
	find_text(main.overlay, "按键绑定").pressed.emit()
	find_text(main.overlay, "恢复默认").pressed.emit()
	find_text(main.overlay, "完成").pressed.emit()
	await frames()
	check(DisplayServer.window_get_size() == original, "Reset, binding tab and Done preserve custom size")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await frames()
	var maximized_size := DisplayServer.window_get_size()
	main.show_settings("menu")
	for control in find_class(main.overlay, "HSlider"): control.value += control.step
	await frames()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED and DisplayServer.window_get_size() == maximized_size, "Changing settings preserves maximized window")
	var spin: SpinBox = find_class(main.overlay, "SpinBox")[0]
	find_text(main.overlay, "无限帧率").button_pressed = false
	spin.get_line_edit().grab_focus()
	press(KEY_F11)
	await frames()
	check(main.window_mode.is_fullscreen(), "Fullscreen shortcut works while FPS text field has focus")
	check(main.fullscreen_check.button_pressed, "Fullscreen checkbox tracks shortcut")
	for control in find_class(main.overlay, "HSlider"): control.value += control.step
	find_text(main.overlay, "恢复默认").pressed.emit()
	await frames()
	check(main.window_mode.is_fullscreen(), "Settings and reset preserve fullscreen")
	press(KEY_F11)
	await frames()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "Leaving fullscreen restores maximized state")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(original)
	await frames()
	main.set_fullscreen(true)
	await frames()
	main.set_fullscreen(false)
	await frames()
	check(DisplayServer.window_get_size() == original, "Leaving fullscreen restores custom window dimensions")
	find_text(main.overlay, "按键绑定").pressed.emit()
	main.binding_buttons["fullscreen0"].pressed.emit()
	press(KEY_F10)
	await frames()
	press(KEY_F11)
	await frames()
	check(not main.window_mode.is_fullscreen(), "Old fullscreen key becomes inactive after rebinding")
	press(KEY_F10)
	await frames()
	check(main.window_mode.is_fullscreen(), "New fullscreen key works from binding tab")
	main.set_fullscreen(false)
	# A complete press/release between physics ticks must survive the real
	# main scene input path, including a remapped jump action.
	main.start_episode(0)
	main.set_physics_process(false)
	main.sim.entities.clear()
	main.sim.terrain.load_tiles("0".repeat(713))
	main.sim.ninja.reset(Vector2(34, 300))
	main.sim.step(NinjaInputFrame.LEFT)
	press(KEY_SPACE)
	Input.flush_buffered_events()
	main._physics_process(NinjaSimulation.DT)
	check(main.sim.ninja.just_jumped, "Fast key down/up between physics ticks still wall-jumps through main input")
	check(not main.sim.ninja.jumped, "Fast tap does not become a held jump")
	main.settings.bindings.jump = [KEY_X, 0, 0]
	NinjaBindings.install(main.settings.bindings)
	main.sim.ninja.reset(Vector2(34, 300))
	main.sim.step(NinjaInputFrame.LEFT)
	press(KEY_X)
	Input.flush_buffered_events()
	main._physics_process(NinjaSimulation.DT)
	check(main.sim.ninja.just_jumped, "Fast tap works with a user-remapped jump key")
	main.sim.ninja.jump_buffer = NinjaBody.JUMP_BUFFER
	main.show_pause()
	main.resume()
	main.set_physics_process(false)
	check(main.sim.ninja.jump_buffer == 0 and not NinjaInputFrame.pending_jump, "Resuming clears stale queued jump requests")
	print("WINDOW_TEST_RESULT: ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
