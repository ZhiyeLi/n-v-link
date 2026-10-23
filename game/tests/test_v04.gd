extends SceneTree
var failures: Array[String] = []
var checks := 0
var metrics := {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func fixture() -> Dictionary:
	return {"id": "v04", "episode": 0, "slot": 0, "title": "test", "tiles": "0".repeat(713), "entities": [{"type": 5, "params": [300, 566]}]}

func _initialize() -> void: call_deferred("run")

func find_text(parent: Node, text: String) -> Node:
	for child in parent.get_children():
		if child is Button and child.text == text: return child
		var result := find_text(child, text)
		if result != null: return result
	return null

func run() -> void:
	var sim := NinjaSimulation.new()
	var samples := []
	for speed in [60.0, 144.0, 216.0, 400.0]:
		for acceleration in [0.25, 1.0, 4.0]:
			for air in [false, true]:
				sim.load_level(fixture())
				sim.ninja.max_speed = speed
				sim.acceleration = acceleration
				for i in range(1800):
					sim.ninja.pos = Vector2(300, 300 if air else 566)
					sim.ninja.on_floor = not air
					sim.ninja.velocity.y = 0
					sim.step(NinjaInputFrame.RIGHT)
				check(absf(sim.ninja.velocity.x - speed) < 0.01, "Configured cap reached independently of acceleration and grounded state")
				samples.append([speed, acceleration, air, sim.ninja.velocity.x])
	check(NinjaBody.SPEED > NinjaSimulation.FLOOR_GUARD_SPEED and NinjaBody.SPEED / NinjaSimulation.FLOOR_GUARD_SPEED < 1.1, "Default player is slightly faster than floor guard")
	check(sim.configuration().max_speed == 400, "Replay configuration reserves explicit maximum speed")
	metrics.speeds = samples
	var directory := ProjectSettings.globalize_path("res://.local/v04")
	var skins := NinjaSkins.new(directory)
	skins.reset_all()
	var wide := Image.create(1600, 800, false, Image.FORMAT_RGBA8)
	wide.fill(Color.TRANSPARENT)
	wide.fill_rect(Rect2i(200, 200, 1200, 400), Color(1, 0.2, 0.4, 1))
	var path := directory.path_join("wide.png")
	wide.save_png(path)
	var source_hash := FileAccess.get_sha256(path)
	check(skins.import_file("guard", path).ok, "Real PNG import succeeds")
	var normalized := skins.texture("guard").get_image()
	var region := normalized.get_used_rect()
	check(normalized.get_size() == Vector2i(256, 192), "Guard texture has canonical dimensions")
	check(absf(float(region.size.x) / region.size.y - 3.0) < 0.06, "Transparent cropping preserves artwork aspect ratio")
	check(FileAccess.get_sha256(path) == source_hash, "Source image remains unchanged")
	var reload := NinjaSkins.new(directory)
	check(reload.texture("guard") != null, "Imported copy reloads across sessions")
	var tall := Image.create(80, 400, false, Image.FORMAT_RGB8)
	tall.fill(Color.WHITE)
	tall.save_jpg(directory.path_join("tall.jpg"))
	check(skins.import_file("thwump", directory.path_join("tall.jpg")).ok, "JPG upload is normalized")
	tall.save_webp(directory.path_join("tall.webp"))
	check(skins.import_file("bounce", directory.path_join("tall.webp")).ok, "WebP upload is normalized")
	var transparent := Image.create(50, 50, false, Image.FORMAT_RGBA8)
	transparent.fill(Color.TRANSPARENT)
	check(not skins.install_image("guard", transparent, "empty").ok and skins.texture("guard") != null, "Empty import cannot replace a valid current skin")
	check(not skins.import_file("../escape", path).ok, "Unknown slots are rejected")
	var bad := FileAccess.open(directory.path_join("invalid.png"), FileAccess.WRITE)
	bad.store_string("not an image"); bad.close()
	check(not skins.import_file("guard", directory.path_join("invalid.png")).ok, "Invalid image reports failure")
	check(skins.install_demo().ok and skins.entries.size() == 16, "Both requested demo cases install through the normal importer")
	var rig := NinjaRig.new()
	root.add_child(rig)
	skins.apply_rig(rig)
	for part in rig.parts.values(): check(part.texture != null and part.texture_region.size.x > 0, "Every character part has a visible imported image")
	for stance in ["run", "rise", "fall", "wall_climb", "wall_slide", "wall_jump"]:
		rig.set_pose(NinjaAnimation.make_pose(stance, 1.2, 216, 70, 1))
		for part in rig.parts.values(): check(part.transform.is_finite(), "Skinned animation transforms stay valid")
	sim.load_level(fixture())
	sim.ninja.kill("test", true, sim.ninja.pos)
	sim.finish_death()
	rig.set_ragdoll(sim.ragdoll, 1)
	check(rig.parts.head.texture != null and rig.parts.left_forearm.texture != null, "Death preserves uploaded body-part textures")
	rig.queue_free()
	var main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = directory.path_join("settings.json")
	main.skins = skins
	root.add_child(main)
	main.set_physics_process(false)
	await process_frame
	check(find_text(main.menu, "自定义贴图") != null, "Home screen exposes texture customization")
	find_text(main.menu, "自定义贴图").pressed.emit()
	check(main.state == "skins" and main.skin_screen.rows.get_child_count() == 13, "Entity texture slots are available")
	find_text(main.skin_screen, "角色部位").pressed.emit()
	check(main.skin_screen.rows.get_child_count() == 12, "All twelve player body parts are editable")
	main.skin_screen.slot = "player_head"
	main.skin_screen.selected_file_slot = "player_head"
	main.skin_screen.dialog.file_selected.emit(path)
	check(skins.entries.player_head.title == "wide.png", "File dialog selection invokes the importer")
	find_text(main.skin_screen, "清空当前槽").pressed.emit()
	check(skins.texture("player_head") == null and skins.texture("drone_patrol") != null, "Per-slot reset leaves other skins intact")
	find_text(main.skin_screen, "返回首页").pressed.emit()
	main.show_settings("menu")
	find_text(main.overlay, "显示碰撞箱").button_pressed = true
	main.settings.max_speed = 250
	main.apply_settings()
	check(main.world.show_collisions and main.sim.ninja.max_speed == 250, "Settings apply collision visibility and maximum speed")
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.settings.path))
	check(stored.show_collisions and stored.max_speed == 250, "New settings persist")
	main.show_menu()
	main.start_episode(0)
	await process_frame
	check(main.world.collisions.visible and main.sim.ninja.max_speed == 250, "Both new settings survive starting a level")
	main.retry()
	check(main.sim.ninja.max_speed == 250, "Retry preserves chosen maximum speed")
	skins.reset_all()
	check(NinjaSkins.new(directory).entries.is_empty(), "Reset all persists across reload")
	main.queue_free()
	await process_frame
	var report := {"checks": checks, "failures": failures, "metrics": metrics}
	FileAccess.open(ProjectSettings.globalize_path("res://../logs/v04-tests.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("V04_TEST_RESULT: ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
