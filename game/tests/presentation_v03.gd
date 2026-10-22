extends SceneTree
var gallery := Node2D.new()
var main: Node

func _initialize() -> void: call_deferred("run")

func caption(text: String, at: Vector2, size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", Color("282830"))
	label.add_theme_font_size_override("font_size", size)
	gallery.add_child(label)

func pose(stance: String, at: Vector2, cycle: float, vertical: float = 0, side: float = 1) -> NinjaRig:
	var rig := NinjaRig.new()
	gallery.add_child(rig)
	rig.position = at
	rig.scale = Vector2(3.1, 3.1)
	rig.set_pose(NinjaAnimation.make_pose(stance, cycle, 144, vertical, side))
	return rig

func run() -> void:
	Engine.max_fps = 60
	root.add_child(gallery)
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1024, 0), Vector2(1024, 768), Vector2(0, 768)])
	paper.color = Color("e4e4e9")
	gallery.add_child(paper)
	caption("N 1.4 / reconstructed joint trajectories", Vector2(35, 18), 24)
	caption("RUN  /  one cycle over 64.8 pixels", Vector2(35, 67))
	for i in range(8):
		pose("run", Vector2(77 + i * 124, 148), i * TAU / 8)
		caption(str(i * 9 + 13), Vector2(65 + i * 124, 197), 14)
	caption("AIR  /  vertical velocity drives ascent, apex and fall", Vector2(35, 237))
	var verticals := [-120, -30, 0, 30, 120]
	for i in range(5):
		pose("air", Vector2(93 + i * 158, 325), 0, verticals[i])
		caption(str(verticals[i]) + " px/s", Vector2(57 + i * 158, 371), 14)
	caption("WALL", Vector2(837, 237))
	pose("wall_climb", Vector2(850, 320), 0.5, -60)
	pose("wall_slide", Vector2(950, 320), 0.5, 17)
	caption("rise        slide", Vector2(824, 371), 14)
	caption("PATROL             SCOUT / IDLE       SCOUT / CHASE", Vector2(35, 430), 16)
	var icons := Node2D.new()
	icons.position = Vector2(100, 503)
	icons.scale = Vector2(3, 3)
	gallery.add_child(icons)
	icons.draw.connect(func():
		NinjaDroneIcon.draw_icon(icons, Vector2.ZERO, false, false, Vector2.RIGHT, 0)
		NinjaDroneIcon.draw_icon(icons, Vector2(65, 0), true, false, Vector2.RIGHT, 0)
		NinjaDroneIcon.draw_icon(icons, Vector2(130, 0), true, true, Vector2.RIGHT, 0.1))
	icons.queue_redraw()
	caption("DEATH / same pose becomes a simulated body", Vector2(35, 581), 18)
	for explosive in [false, true]:
		var sim := NinjaSimulation.new()
		sim.load_level({"id": "gallery", "episode": 0, "slot": 0, "title": "", "tiles": "0".repeat(713), "entities": [{"type": 5, "params": [300, 300]}]})
		sim.ninja.motion = NinjaBody.Motion.RUNNING
		sim.ninja.run_distance = 20
		sim.ninja.kill("preview", explosive, Vector2(298, 300))
		sim.finish_death()
		for i in range(22): sim.ragdoll.step(sim.terrain, NinjaSimulation.DT)
		var parent := Node2D.new()
		gallery.add_child(parent)
		parent.position = Vector2(670 if explosive else 180, 670) - Vector2(300, 300) * 2.5
		parent.scale = Vector2(2.5, 2.5)
		var rig := NinjaRig.new()
		parent.add_child(rig)
		rig.set_ragdoll(sim.ragdoll, 1)
		caption("EXPLOSIVE / 4 detached limbs" if explosive else "INTACT / shared joints", Vector2(530 if explosive else 63, 728), 15)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/v03-presentation.png"))
	print("PRESENTATION_CAPTURE_RESULT=", result)
	quit(result)
