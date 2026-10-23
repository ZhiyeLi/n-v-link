extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("GUI_CHECK ",ok,": ",message)
	if not ok: failed=true
func capture(viewport: Viewport,name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/"+name+".png"))
func run() -> void:
	Engine.max_fps=60
	var main = load("res://scenes/main.tscn").instantiate()
	var base := ProjectSettings.globalize_path("res://.local/v061-gallery-"+str(Time.get_ticks_usec()))
	main.settings=NinjaSettings.new(true); main.settings.path=base.path_join("settings.json")
	main.skins=NinjaSkins.new(base); main.skins.reset_all()
	root.add_child(main); main.set_physics_process(false); main.show_skins()
	main.skin_screen.open_presets()
	var preset: NinjaPresetScreen=main.skin_screen.get_child(main.skin_screen.get_child_count()-1)
	check(preset.library.size()==3,"Three bundled full presets")
	for i in range(preset.library.size()):
		if preset.library[i].name=="白金·临光": preset.selector.select(i)
	preset.load_selected()
	check(main.skins.preset_name=="白金·临光","UI loads new preset")
	await capture(preset,"v061-presets")
	preset.name_field.text="测试副本 / Test copy"; preset.save_named(true)
	check(main.skins.preset_name=="测试副本 / Test copy","UI creates independent full copy")
	preset.save_named(false)
	check(preset.status.text.contains("Saved"),"UI saves existing package")
	preset.queue_free(); await process_frame
	main.skin_screen.slot="drone_scout"; main.skin_screen.refresh()
	main.skin_screen.state_picker.select(1); main.skin_screen.refresh_selection()
	await capture(root,"v061-platinum-nearl")
	main.skin_screen.open_prts()
	var fetch: NinjaPRTSScreen=main.skin_screen.get_child(main.skin_screen.get_child_count()-1)
	fetch.character.text="临光"
	await fetch.start_download()
	check(fetch.last_result.ok and fetch.last_result.downloads.size()==9,"Real native HTTPS default model download: "+str(fetch.last_result.get("message","")))
	await capture(fetch,"v061-fetch-success")
	fetch.character.text="NVLink不存在的测试角色061"
	await fetch.start_download()
	check(not fetch.last_result.ok and not fetch.running and not fetch.start_button.disabled,"Real HTTP failure reports and restores UI")
	await capture(fetch,"v061-fetch-failure")
	fetch.queue_free(); main.queue_free(); await process_frame
	print("CAPTURE_RESULT=",1 if failed else 0)
	quit(1 if failed else 0)
