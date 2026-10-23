extends SceneTree
func _initialize() -> void: call_deferred("run")

func label(canvas: Node, text: String, at: Vector2) -> void:
	var item := Label.new()
	item.text = text
	item.position = at
	item.add_theme_color_override("font_color", Color("282830"))
	canvas.add_child(item)

func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1080,800)
	var canvas := Control.new()
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.size = Vector2(1080,800)
	bg.color = Color("e4e4e9")
	canvas.add_child(bg)
	for i in range(2):
		label(canvas, ["LASER / DARK RED", "CHAINGUN / BLACK"][i], Vector2(30+i*530,20))
		var icon := Node2D.new()
		icon.set_script(load("res://view/world_view.gd"))
		icon.preview_only = true
		canvas.add_child(icon)
		icon.preview_entity(["drone_laser","drone_chain"][i])
		icon.scale = Vector2(4,4)
		icon.position = Vector2(200+i*530,90)
	var ticks := [45,90,270,330,470,45]
	var captions := ["CHARGE 0.375s / SAFE WARNING", "FIRING 0.00s / PLAYER DODGED",
		"FIRING 1.50s / SAME LOCKED RAY", "COOLDOWN / BEAM OFF",
		"NEXT ACQUISITION / NEW DIRECTION", "CUSTOM TEXTURE / SAME WARNING"]
	for i in range(6):
		var x := 20 + (i%2)*530
		var y := 160 + (i/2)*210
		label(canvas, captions[i], Vector2(x,y))
		var container := SubViewportContainer.new()
		container.position = Vector2(x,y+30)
		canvas.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(510,170)
		container.add_child(viewport)
		var sim := NinjaSimulation.new()
		sim.load_level({"id":"laser-gallery","episode":0,"slot":0,"tiles":"0".repeat(713),
			"entities":[{"type":5,"params":[348,108]}, {"type":6,"params":[108,108,2,0,1,0]}]})
		var e: Dictionary = sim.entities[0]
		sim.update_drone(e)
		sim.ninja.pos = Vector2(348,220)
		sim.ninja.previous_pos = sim.ninja.pos
		for tick in range(ticks[i]): sim.update_drone(e)
		e.previous = e.pos
		var world := Node2D.new()
		world.set_script(load("res://view/world_view.gd"))
		world.paused = true
		if i == 5:
			var skins := NinjaSkins.new(ProjectSettings.globalize_path("res://.local/v053-gallery"))
			var custom := Image.create(16,16,false,Image.FORMAT_RGBA8)
			custom.fill(Color("387db8"))
			skins.textures["drone_laser"] = ImageTexture.create_from_image(custom)
			world.skins = skins
		viewport.add_child(world)
		world.load_simulation(sim)
		world.scale = Vector2(0.68,0.68)
		world.position = -Vector2(24,24)*0.68
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var code := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/v053-lasers.png"))
	print("CAPTURE_RESULT=",code)
	quit(code)
