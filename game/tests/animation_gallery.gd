extends SceneTree
var elapsed := 0
var gallery := Control.new()
var rigs: Array[NinjaRig] = []
var poses := ["idle", "run", "takeoff", "rise", "fall", "wall_climb", "wall_slide", "wall_jump"]

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	Engine.max_fps = 60
	root.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("e4e4e9")
	background.size = Vector2(1024, 768)
	gallery.add_child(background)
	for i in range(8):
		var cell := Vector2(132 + (i % 4) * 250, 202 + (i / 4) * 330)
		for mirror in [1, -1]:
			var rig := NinjaRig.new()
			rig.position = cell + Vector2(-45 if mirror == 1 else 45, 0)
			rig.scale = Vector2(mirror * 3.8, 3.8)
			gallery.add_child(rig)
			rig.set_pose(NinjaRig.make_pose(poses[i], 0.6, 144, 150, 1))
			rigs.append(rig)
		var label := Label.new()
		label.text = poses[i]
		label.position = cell + Vector2(-100, 74)
		label.size = Vector2(200, 35)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color("282830"))
		gallery.add_child(label)

func _process(_delta: float) -> bool:
	elapsed += 1
	if elapsed == 35:
		capture.call_deferred()
	return false

func capture() -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../logs/animation.png"))
	print("ANIMATION_CAPTURE_RESULT=", result)
	quit(result)
