extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps=60
	var skins := NinjaSkins.new(ProjectSettings.globalize_path("res://.local/layers-gallery-"+str(Time.get_ticks_usec())))
	if not NinjaSkinPresets.load_file(skins,"res://data/presets/platinum_nearl.nvskin").ok: quit(1); return
	var gallery := Node2D.new(); root.add_child(gallery)
	var bg := Polygon2D.new(); bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,768),Vector2(0,768)]); bg.color=Color("e4e4e9"); gallery.add_child(bg)
	for row in range(4):
		var label := Label.new(); label.text=["PLATINUM / RUN RIGHT","PLATINUM / RUN LEFT","NEARL / MOVE RIGHT","NEARL / DASH LEFT"][row]
		label.position=Vector2(28,8+row*190); label.add_theme_color_override("font_color",Color("292932")); gallery.add_child(label)
		for col in range(6):
			var direction := -1 if row%2 else 1
			if row<2:
				var rig := NinjaRig.new(); gallery.add_child(rig); skins.apply_rig(rig)
				rig.set_pose(NinjaAnimation.make_pose("run",float(col)/6*TAU,216,0,1),1,"run")
				rig.scale=Vector2(direction*3.4,3.4); rig.position=Vector2(95+col*166,161+row*190)
			else:
				var sprite := Sprite2D.new(); gallery.add_child(sprite)
				sprite.texture=skins.frame_at("drone_scout","move" if row==2 else "dash",float(col)/6*32/24/(1 if row==2 else 1.65))
				sprite.scale=Vector2(direction*0.85,0.85); sprite.position=Vector2(95+col*166,105+row*190)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var code := image.save_png(ProjectSettings.globalize_path("res://../logs/v061-layers-fixed.png"))
	print("CAPTURE_RESULT=",code); quit(code)
