extends SceneTree
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1024,768)
	var canvas := Control.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.size = Vector2(1024,768)
	bg.color = Color("e4e4e9")
	canvas.add_child(bg)
	for row in range(2):
		var skins := NinjaSkins.new(ProjectSettings.globalize_path("res://.local/v052-gallery-" + str(row)))
		skins.reset_all()
		if row == 1: skins.install_demo()
		for col in range(3):
			var label := Label.new()
			label.text = ("DEFAULT / " if row == 0 else "EXUSIAI / ") + ["ELECTRIC", "EXPLOSION", "FALL"][col]
			label.position = Vector2(20+col*334, 30+row*350)
			label.add_theme_color_override("font_color", Color("282830"))
			canvas.add_child(label)
			var container := SubViewportContainer.new()
			container.position = Vector2(20+col*334,70+row*350)
			canvas.add_child(container)
			var viewport := SubViewport.new()
			viewport.size = Vector2i(314,270)
			container.add_child(viewport)
			var sim := NinjaSimulation.new()
			sim.load_level({"id":"gallery","episode":0,"slot":0,"tiles":"0".repeat(713),"entities":[{"type":5,"params":[300,560]}]})
			var kinds := [NinjaBody.DeathKind.ELECTRIC,NinjaBody.DeathKind.EXPLOSIVE,NinjaBody.DeathKind.FALL]
			sim.ninja.kill("preview", col==1, Vector2(288,558), Vector2.ZERO, kinds[col])
			sim.finish_death()
			for tick in range(20 if col==1 else 12): sim.step(0)
			var world := Node2D.new()
			world.set_script(load("res://view/world_view.gd"))
			world.skins = skins
			world.paused = true
			viewport.add_child(world)
			world.load_simulation(sim)
			world.scale = Vector2(3.5,3.5)
			world.position = Vector2(157,185) - Vector2(300,560)*3.5
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var code := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/v052-deaths.png"))
	print("CAPTURE_RESULT=",code)
	quit(code)
