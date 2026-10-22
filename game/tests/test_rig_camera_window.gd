extends SceneTree
var main: Node
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); printerr("FAIL: ", text)
func frames() -> void:
	for i in range(8): await process_frame
func capture(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/" + name + ".png")) == OK, "Capture " + name)
func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = ProjectSettings.globalize_path("res://.local/rig_camera_settings.json")
	main.settings.max_fps = 60
	root.add_child(main)
	main.set_physics_process(false)
	main.skins.reset_all()
	main.show_skins()
	main.skin_screen.slot = "guard"
	main.skin_screen.refresh()
	await capture("v05-default-guard")
	main.skin_screen.slot = "thwump"
	main.skin_screen.refresh()
	await capture("v05-default-thwump")
	main.skins.install_demo()
	main.skin_screen.select_category("player")
	main.skin_screen.slot = "player_left_calf"
	main.skin_screen.refresh()
	main.skin_screen.edit_layout()
	await frames()
	var editor: NinjaRigEditor = main.skin_screen.rig_editor
	check(editor.visible and editor.canvas.image_rect.size.x > 0, "Anchor editor opens with actual image")
	var old_anchor: float = main.skins.layout.parts.left_calf.pivot_x
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = editor.canvas.image_rect.position + Vector2(0.2, 0.5) * editor.canvas.image_rect.size
	editor.canvas._gui_input(pointer)
	pointer.pressed = false
	editor.canvas._gui_input(pointer)
	check(not is_equal_approx(main.skins.layout.parts.left_calf.pivot_x, old_anchor), "Dragging changes the near joint")
	editor.fields.width.value *= 1.2
	await frames()
	check(editor.rig.layout.parts.left_calf.width == main.skins.layout.parts.left_calf.width, "Preview updates from width changes")
	main.skins.layout = editor.originals.duplicate(true)
	main.skins.save()
	editor.sync_fields()
	await capture("v05-rig-editor")
	editor.queue_free()
	await frames()
	main.show_menu()
	main.start_episode(50)
	main.settings.show_collisions = true
	main.apply_settings()
	main.sim.ninja.reset(Vector2(310, 144))
	main.map_view.set_view_policy({"zoom": 2, "mode": "follow", "snap": true})
	await capture("v05-camera-follow")
	check(main.map_view.visible_rect.size.x < 792 and main.hud.visible, "Zoom crops the map and keeps HUD")
	main.map_view.set_targets([Vector2(150, 170), Vector2(650, 420)])
	main.map_view.set_view_policy({"mode": "group", "snap": true})
	await capture("v05-camera-group")
	for point in main.map_view.camera.targets: check(main.map_view.visible_rect.has_point(point), "Group view contains target")
	main.map_view.set_view_policy({"mode": "fixed", "zoom": 3, "center": Vector2(500, 350), "snap": true})
	await capture("v05-camera-fixed")
	check(main.map_view.visible_rect.get_center().is_equal_approx(Vector2(500, 350)), "View policy changes while running")
	main.queue_free()
	await process_frame
	print("RIG_CAMERA_RESULT: ", JSON.stringify({"checks": checks, "failures": failures}))
	print("RIG_CAMERA_CAPTURE_RESULT=", 0 if failures.is_empty() else 1)
	quit(0 if failures.is_empty() else 1)
