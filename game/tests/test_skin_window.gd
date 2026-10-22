extends SceneTree
var main: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); printerr("FAIL: ", description)

func frames() -> void:
	for i in range(5): await process_frame

func select_file(node: Node, filename: String) -> bool:
	if node is ItemList:
		for index in range(node.item_count):
			if node.get_item_text(index) == filename:
				node.select(index)
				node.item_selected.emit(index)
				return true
	for child in node.get_children(true):
		if select_file(child, filename): return true
	return false

func press(code: int) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = ProjectSettings.globalize_path("res://.local/skin_window_settings.json")
	main.settings.max_fps = 60
	root.add_child(main)
	main.set_physics_process(false)
	await frames()
	DisplayServer.window_set_size(Vector2i(1200, 850))
	await frames()
	var window_size := DisplayServer.window_get_size()
	main.skins.reset_all()
	check(main.skins.install_demo().ok, "Demo images install in a graphical session")
	main.show_skins()
	await frames()
	press(KEY_R)
	check(main.state == "skins", "Retry cannot interrupt customization")
	main.skin_screen.open_import()
	await frames()
	check(main.skin_screen.dialog.visible, "File chooser opens")
	check(DisplayServer.window_get_size() == window_size, "File chooser preserves custom window size")
	press(KEY_F11)
	await frames()
	check(main.window_mode.is_fullscreen(), "Fullscreen shortcut remains available with the chooser open")
	press(KEY_F11)
	await frames()
	check(DisplayServer.window_get_size() == window_size, "Chooser fullscreen round trip preserves size")
	main.skin_screen.dialog.current_dir = ProjectSettings.globalize_path("res://data/demo_skins")
	await frames()
	check(select_file(main.skin_screen.dialog, "drone_patrol.png"), "Real file-list selection locates the image")
	await frames()
	check(not main.skin_screen.dialog.get_ok_button().disabled, "Selecting a valid image enables Import")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/skin-import-dialog.png")) == OK, "File chooser screenshot")
	# Activate the actual dialog's Open control, exercising validation and file_selected.
	main.skin_screen.dialog.get_ok_button().pressed.emit()
	await frames()
	check(not main.skin_screen.dialog.visible, "Open closes the chooser")
	check(main.skins.entries.drone_patrol.title == "drone_patrol.png", "Open imports the selected file")
	check(DisplayServer.window_get_size() == window_size, "Import preserves custom window size")
	main.skin_screen.select_category("player")
	for child in main.skin_screen.panel.get_children():
		if child is OptionButton:
			child.select(4)
			child.item_selected.emit(4)
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/skin-player-preview.png")) == OK, "Skinned wall-slide screenshot")
	press(KEY_F11)
	await frames()
	check(main.window_mode.is_fullscreen(), "Fullscreen shortcut works on customization page")
	main.skins.remove("player_head")
	main.skin_screen.refresh()
	await frames()
	check(main.window_mode.is_fullscreen(), "Restoring a texture preserves fullscreen")
	press(KEY_F11)
	await frames()
	check(DisplayServer.window_get_size() == window_size, "Leaving fullscreen restores the customization window size")
	main.show_menu()
	main.start_episode(0)
	main.settings.show_collisions = true
	main.apply_settings()
	await frames()
	check(main.world.collisions.visible, "Collision layer toggles in the rendered world")
	check(main.world.rig.parts.body.texture != null, "World renders the imported player body")
	main.settings.show_collisions = false
	main.apply_settings()
	await frames()
	check(not main.world.collisions.visible, "Collision layer can be hidden immediately")
	var report := {"checks": checks, "failures": failures}
	FileAccess.open(ProjectSettings.globalize_path("res://../logs/skin-window-tests.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SKIN_WINDOW_TEST_RESULT: ", JSON.stringify(report))
	print("SKIN_WINDOW_CAPTURE_RESULT=", 0 if failures.is_empty() else 1)
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
