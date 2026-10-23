extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func _initialize() -> void:
	call_deferred("run")

func find_text(parent: Node, text: String) -> Node:
	for child in parent.get_children():
		if child is Button and child.text == text: return child
		var nested := find_text(child, text)
		if nested != null: return nested
	return null

func find_class(parent: Node, kind: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		if child.is_class(kind): result.append(child)
		result.append_array(find_class(child, kind))
	return result

func key(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = ProjectSettings.globalize_path("res://.local/test_ui_settings.json")
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	check(main.state == "menu", "Boots to menu")
	check(find_text(main.menu, "99") != null, "All 100 episode choices available")
	find_text(main.menu, "00").pressed.emit()
	check(main.state == "playing" and main.sim.level.id == "00-0", "Episode selector starts original first level")
	for i in range(30): main._physics_process(1.0 / 120)
	find_text(main.hud, "暂停").pressed.emit()
	check(main.state == "paused" and main.world.paused, "Pause stops simulation and presentation")
	find_text(main.overlay, "设置").pressed.emit()
	check(main.state == "settings", "Pause opens settings")
	var unlimited = find_text(main.overlay, "无限帧率")
	unlimited.button_pressed = false
	check(main.settings.max_fps == 144 and Engine.max_fps == 144, "FPS UI activates manual cap")
	for child in find_class(main.overlay, "SpinBox"):
		if child.name == "MaxFPS": child.value = 165
	for child in find_class(main.overlay, "HSlider"):
		if child.max_value == 4: child.value = 2.5
	check(main.settings.max_fps == 165 and Engine.max_fps == 165, "Manual FPS spinbox applies")
	check(main.sim.acceleration == 2.5, "Acceleration slider applies to simulation")
	unlimited.button_pressed = true
	check(Engine.max_fps == 0, "Unlimited toggle removes cap")
	find_text(main.overlay, "按键绑定").pressed.emit()
	check(main.binding_buttons.size() == 21, "Every game action has three editable bindings")
	main.binding_buttons["left0"].pressed.emit()
	main._input(key(KEY_H))
	check(main.settings.bindings.left[0] == KEY_H, "Captured key replaces primary left binding")
	Input.parse_input_event(key(KEY_H))
	await process_frame
	check((NinjaInputFrame.sample() & NinjaInputFrame.LEFT) != 0, "New binding produces movement input")
	Input.parse_input_event(key(KEY_H, false))
	await process_frame
	check((NinjaInputFrame.sample() & NinjaInputFrame.LEFT) == 0, "Key release stops movement input")
	Input.parse_input_event(key(KEY_LEFT))
	await process_frame
	check((NinjaInputFrame.sample() & NinjaInputFrame.LEFT) == 0, "Removed binding no longer moves player")
	Input.parse_input_event(key(KEY_LEFT, false))
	main.binding_buttons["jump0"].pressed.emit()
	main._input(key(KEY_H))
	check(main.binding_action == "jump" and main.binding_notice.text.contains("已用于"), "Conflicting binding rejected without stealing the key")
	find_text(main.overlay, "取消绑定").pressed.emit()
	main.binding_buttons["fullscreen0"].pressed.emit()
	main._input(key(KEY_F10))
	check(main.settings.bindings.fullscreen[0] == KEY_F10, "Fullscreen is remappable")
	var data = JSON.parse_string(FileAccess.get_file_as_string(main.settings.path))
	check(data.bindings.left[0] == KEY_H and data.bindings.fullscreen[0] == KEY_F10, "Bindings persist to disk")
	find_text(main.overlay, "恢复默认").pressed.emit()
	check(main.settings.bindings == NinjaBindings.DEFAULTS, "Binding defaults can be restored")
	find_text(main.overlay, "完成").pressed.emit()
	check(main.state == "paused", "Closing settings returns to pause")
	find_text(main.overlay, "继续").pressed.emit()
	check(main.state == "playing" and not main.world.paused, "Resume works")
	main.sim.time_left = 0.001
	main._physics_process(1.0 / 120)
	check(main.state == "dead", "Death shows retry banner")
	var banner: Panel = main.overlay.get_node("DeathBanner")
	check(banner.position.y + banner.size.y <= main.map_view.position.y, "Death notice stays above the playfield")
	check(main.overlay.get_child_count() == 1 and not main.world.paused, "Death has no dimming veil and does not freeze presentation")
	var death_tick: int = main.sim.tick
	for i in range(30): main._physics_process(NinjaSimulation.DT)
	check(main.sim.tick == death_tick + 30 and main.sim.ragdoll.age > 0.2, "Main scene continues physics while death banner is visible")
	find_text(main.hud, "设置").pressed.emit()
	find_text(main.overlay, "完成").pressed.emit()
	check(main.state == "dead" and not main.world.paused, "Settings returns to the running death scene")
	find_text(main.overlay, "重试  " + main.key_hint("confirm")).pressed.emit()
	check(main.state == "playing" and main.sim.time_left == 90, "Retry restores level-start time")
	check(not main.sim.ragdoll.active, "Retry clears previous corpse")
	main.sim.won = true
	main._physics_process(1.0 / 120)
	find_text(main.overlay, "下一关  " + main.key_hint("confirm")).pressed.emit()
	check(main.level_index == 1 and main.sim.level.id == "00-1", "Completion advances to next original map")
	main.sim.ninja.velocity = Vector2(100, 0)
	main.on_focus_lost()
	check(main.state == "paused" and (NinjaInputFrame.sample() & 7) == 0, "Focus loss releases controls and pauses")
	main.queue_free()
	await process_frame
	print("UI_TEST_RESULT: ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
