extends SceneTree
var gallery := Node2D.new()
var skins: NinjaSkins

func _initialize() -> void: call_deferred("run")

func caption(text: String, at: Vector2, size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", Color("282830"))
	label.add_theme_font_size_override("font_size", size)
	gallery.add_child(label)

func pose(stance: String, at: Vector2, cycle: float, vertical: float = 0, facing: float = 1) -> void:
	var rig := NinjaRig.new()
	gallery.add_child(rig)
	skins.apply_rig(rig)
	rig.position = at
	rig.scale = Vector2(facing * 3.3, 3.3)
	rig.set_pose(NinjaAnimation.make_pose(stance, cycle, 216, vertical, 1), 1, stance)

func run() -> void:
	Engine.max_fps = 60
	skins = NinjaSkins.new(ProjectSettings.globalize_path("res://.local/presentation_v05"))
	skins.reset_all()
	if not skins.install_demo().ok: quit(1); return
	root.add_child(gallery)
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1024, 0), Vector2(1024, 768), Vector2(0, 768)])
	paper.color = Color("e4e4e9")
	gallery.add_child(paper)
	caption("0.5 / PROPORTIONAL ART + CALIBRATED JOINT ANCHORS", Vector2(35, 18), 23)
	caption("RUN / six phases", Vector2(35, 58))
	for i in range(6): pose("run", Vector2(90 + i * 166, 160), i * TAU / 6)
	var air_titles := ["RISE", "APEX", "FALL", "WALL RISE", "WALL SLIDE", "WALL JUMP"]
	for i in range(6): caption(air_titles[i], Vector2(40 + i * 166, 252), 16)
	pose("rise", Vector2(90, 344), 0, -120)
	pose("air", Vector2(256, 344), 0, 0)
	pose("fall", Vector2(422, 344), 0, 90)
	pose("wall_climb", Vector2(588, 344), 0.5, -60)
	pose("wall_slide", Vector2(754, 344), 0.5, 17)
	pose("wall_jump", Vector2(920, 344), 0, -100)
	caption("FACE LEFT        FACE RIGHT", Vector2(35, 457), 16)
	pose("run", Vector2(90, 553), 0.5, 0, -1)
	pose("run", Vector2(256, 553), 0.5)
	caption("SLUG / PATROL       SCOUT / UNCHANGED", Vector2(389, 457), 16)
	var icons := Node2D.new()
	icons.position = Vector2(470, 552)
	icons.scale = Vector2(4.5, 4.5)
	gallery.add_child(icons)
	icons.draw.connect(func():
		icons.draw_texture_rect(skins.texture("drone_patrol"), Rect2(-11, -11, 22, 22), false)
		icons.draw_arc(Vector2.ZERO, 9, 0, TAU, 40, Color("ce4b58"), 0.3, true)
		NinjaDroneIcon.draw_icon(icons, Vector2(51, 0), true, false, Vector2.RIGHT, 0))
	icons.queue_redraw()
	caption("INTACT DEATH", Vector2(35, 640), 15)
	caption("EXPLOSIVE DEATH", Vector2(495, 640), 15)
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
		parent.position = Vector2(705 if explosive else 215, 690) - Vector2(300, 300) * 2.3
		parent.scale = Vector2(2.3, 2.3)
		var rig := NinjaRig.new()
		parent.add_child(rig)
		skins.apply_rig(rig)
		rig.set_ragdoll(sim.ragdoll, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/v05-presentation.png"))
	print("PRESENTATION_CAPTURE_RESULT=", result)
	quit(result)
