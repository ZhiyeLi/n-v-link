extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/"+name+".png"))

func run() -> void:
	Engine.max_fps=60
	var main = load("res://scenes/main.tscn").instantiate()
	var base := ProjectSettings.globalize_path("res://.local/v06-gallery")
	main.settings=NinjaSettings.new(true); main.settings.path=base.path_join("settings.json")
	main.skins=NinjaSkins.new(base); main.skins.reset_all(); main.skins.install_v06_demo()
	root.add_child(main); main.set_physics_process(false)
	main.show_skins(); main.skin_screen.slot="drone_scout"; main.skin_screen.refresh()
	main.skin_screen.state_picker.select(1); main.skin_screen.refresh_selection()
	await capture("v06-animation-ui")
	main.skin_screen.select_category("actor")
	await capture("v06-player-ui")
	var bg := Image.create(792,600,false,Image.FORMAT_RGBA8)
	for y in range(600): bg.fill_rect(Rect2i(0,y,792,1),Color("263e5c").lerp(Color("99b6bd"),float(y)/600))
	main.skins.install_image("background",bg,"Background test")
	main.start_episode(0)
	main.sim.load_level({"id":"v06-gallery","title":"Animation slots","episode":0,"slot":0,"tiles":"0".repeat(713),"entities":[
		{"type":5,"params":[400,300]}, {"type":6,"params":[280,300,2,1,0,0]},
		{"type":6,"params":[500,300,2,0,1,0]}, {"type":6,"params":[600,300,2,0,2,0]}]})
	main.world.load_simulation(main.sim)
	main.map_view.set_view_policy({"zoom":2.0})
	main.world.show_collisions=true
	main.sim.entities[0].chasing=true
	main.sim.update_drone(main.sim.entities[1])
	await capture("v06-world")
	print("CAPTURE_RESULT=0")
	main.queue_free(); await process_frame; quit()
