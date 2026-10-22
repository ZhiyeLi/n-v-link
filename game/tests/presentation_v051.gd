extends SceneTree
var gallery := Node2D.new()
var skins: NinjaSkins
var live_rigs: Array[NinjaRig] = []

func _initialize() -> void: call_deferred("run")

func caption(text: String, at: Vector2, size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", Color("282830"))
	label.add_theme_font_size_override("font_size", size)
	gallery.add_child(label)

func pose(at: Vector2, cycle: float, facing: float = 1, custom: bool = true) -> NinjaRig:
	var rig := NinjaRig.new()
	gallery.add_child(rig)
	if custom: skins.apply_rig(rig)
	rig.position = at
	rig.scale = Vector2(facing * 3.3, 3.3)
	rig.set_pose(NinjaAnimation.make_pose("run", cycle, 216, 0, 1), 1, "run")
	return rig

func run() -> void:
	Engine.max_fps = 60
	skins = NinjaSkins.new(ProjectSettings.globalize_path("res://.local/presentation_v051"))
	skins.reset_all()
	if not skins.install_demo().ok: quit(1); return
	root.add_child(gallery)
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1024, 0), Vector2(1024, 768), Vector2(0, 768)])
	paper.color = Color("e4e4e9")
	gallery.add_child(paper)
	caption("0.5.1 / RUN CYCLE / BOTH LEGS ALTERNATE", Vector2(35, 18), 23)
	for row in range(2):
		for column in range(6):
			var frame := row * 6 + column
			caption("%d / 12" % (frame + 1), Vector2(48 + column * 166, 65 + row * 185), 16)
			pose(Vector2(90 + column * 166, 170 + row * 185), frame * TAU / 12)
	caption("LIVE / RIGHT                   MIRRORED LEFT                    ORIGINAL RIG", Vector2(80, 490), 17)
	live_rigs.append(pose(Vector2(180, 630), 0))
	live_rigs.append(pose(Vector2(480, 630), 0, -1))
	live_rigs.append(pose(Vector2(780, 630), 0, 1, false))
	var folder := ProjectSettings.globalize_path("res://../logs/v051-run")
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in range(36):
		for rig in live_rigs: rig.set_pose(NinjaAnimation.make_pose("run", frame * TAU / 36, 216, 0, 1), 1, "run")
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var result := picture.save_png(folder.path_join("%02d.png" % frame))
		if result != OK: quit(1); return
		if frame == 0: picture.save_png(ProjectSettings.globalize_path("res://../logs/v051-run.png"))
	print("RUN_CAPTURE_RESULT=0")
	quit(0)
