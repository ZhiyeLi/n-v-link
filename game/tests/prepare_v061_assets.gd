extends "res://tests/prepare_demo_skins.gd"
## Offline setup-pose extraction and N-animation retargeting, not Spine playback.
func part_layer(character: String, part: String) -> int:
	# Platinum's head image includes long hair; all limbs and the torso go in front.
	if character=="白金" and part=="head": return 1
	# Nearl's skirt is part of the torso and must occlude both legs throughout the run.
	if character=="临光" and (part.ends_with("thigh") or part.ends_with("calf") or part.ends_with("foot")):
		return 2 if part.begins_with("left_") else 3
	return 8 if part=="head" else (5 if part=="body" else (2 if part.begins_with("left_") else 6))

func prepare_character(character: String, stem: String, groups: Dictionary, head_bone: String, factor: float) -> Dictionary:
	var source := ProjectSettings.globalize_path("res://../sources/input pictures/"+character+"/raw-models/默认-正面")
	var out := ProjectSettings.globalize_path("res://data/preset_assets/"+stem)
	DirAccess.make_dir_recursive_absolute(out)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("setup.json")))
	# Skin attachment storage order differs from Spine slot draw order.
	var order := {}
	for i in range(data.slots.size()): order[data.slots[i].name]=i
	data.attachments.sort_custom(func(a,b): return order[a.slot]<order[b.slot])
	var atlas := ImageTexture.create_from_image(Image.load_from_file(source.path_join(stem+".png")))
	var shoulder := (bone_point(data,groups.left_upper_arm[1])+bone_point(data,groups.right_upper_arm[1]))*0.5
	var points := {}
	for part in groups:
		var start := bone_point(data,head_bone if part=="head" else groups[part][1])
		var end: Vector2
		if part=="head": end=start+Vector2(20,0)
		elif part=="body": end=shoulder
		else:
			var b := bone(data,groups[part][1])
			end=start+Vector2(b.world[0],-b.world[1])*float(b.length)
		points[part]={"start":start,"end":end,"angle":(end-start).angle()}
	var layout := {"version":1,"scale":1.0,"motion":0.65,"parts":{},"reference":"PRTS "+character+" setup anchors; retargeted N animations"}
	for part in groups:
		var img := await render_group(data,atlas,groups[part][0],groups[part][1])
		var pivot := image_anchor(points[part].start)
		var tip := image_anchor(points[part].end)
		var offset := Vector2.ZERO
		var parent: String=NinjaRig.PARENTS[part]
		if not parent.is_empty():
			var parent_end: Vector2=points[parent].start if part.ends_with("thigh") else points[parent].end
			offset=(points[part].start-parent_end).rotated(-points[parent].angle)*factor
		layout.parts[part]={"width":last_render.used.size.x/last_render.scale*factor,
			"pivot_x":pivot.x,"pivot_y":pivot.y,"tip_x":tip.x,"tip_y":tip.y,
			"offset_x":offset.x,"offset_y":offset.y,"angle":0.0,"reference_angle":points[part].angle,
			"layer":part_layer(character,part)}
		NinjaSkins.normalize(img,NinjaSkins.canvas_size("player_"+part)).save_png(out.path_join("player_"+part+".png"))
	var file := FileAccess.open(out.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(layout,"\t")); file.close()
	return {"directory":out,"layout":layout}

func bake_nearl(spec: Dictionary) -> void:
	var viewport := SubViewport.new(); viewport.size=Vector2i(256,256); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var rig := NinjaRig.new(); viewport.add_child(rig)
	rig.layout=spec.layout
	for part in NinjaRig.PARTS:
		rig.set_part_texture(part,ImageTexture.create_from_image(Image.load_from_file(spec.directory.path_join("player_"+part+".png"))))
	var bounds := Rect2()
	for i in range(32):
		rig.set_pose(NinjaAnimation.make_pose("run",float(i)/32*TAU,216,0,1),1,"run")
		bounds=rig.visual_bounds() if i==0 else bounds.merge(rig.visual_bounds())
	var factor := 232/maxf(bounds.size.x,bounds.size.y)
	rig.scale=Vector2.ONE*factor; rig.position=Vector2(128,128)-bounds.get_center()*factor
	var sheet := Image.create(1536,768,false,Image.FORMAT_RGBA8); sheet.fill(Color.TRANSPARENT)
	for i in range(32):
		rig.set_pose(NinjaAnimation.make_pose("run",float(i)/32*TAU,216,0,1),1,"run")
		await process_frame; await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image(); frame.resize(192,192,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(frame,Rect2i(0,0,192,192),Vector2i(i%8,i/8)*192)
	var out := ProjectSettings.globalize_path("res://data/preset_assets/nearl_clip")
	DirAccess.make_dir_recursive_absolute(out)
	sheet.save_png(out.path_join("sheet_0.png"))
	var f := FileAccess.open(out.path_join("clip.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"size":[192,192],"columns":8,"capacity":32,"count":32,"fps":24,"sheets":["sheet_0.png"]})); f.close()
	viewport.queue_free()

func run() -> void:
	Engine.max_fps=120
	await prepare_character("白金","char_204_platnm",{
		"body":[["F_kua","F_xiong","F_yao","F_waitao","F_weibo","F_doupeng","F_doupeng23","F_L_dadoupeng","F_xiedaidi"],"F_L_dadoupeng"],
		"head":[["F_mawei","F_toufa1","F_toufa2","F_youqiangfa","F_zuoqianfa","F_tou","F_dayan","F_er1","F_er2"],""],
		"left_upper_arm":[["F_L_dabi","F_bihuan"],"F_L_dabi"],"left_forearm":[["F_L_shouzhi8","F_L_shouzhi7"],"F_L_shouzhi8"],
		"right_upper_arm":[["F_R_dabi"],"F_R_dabi"],"right_forearm":[["F_R_xiabi","F_R_shouzh7","F_R_shouzh8"],"F_R_xiabi"],
		"left_thigh":[["F_datui"],"F_datui"],"left_calf":[["F_xiaotui"],"F_xiaotui"],"left_foot":[["F_xie"],"F_xie"],
		"right_thigh":[["F_R_datui"],"F_R_datui"],"right_calf":[["F_R_xiaotui"],"F_R_xiaotui"],"right_foot":[["F_R_xie"],"F_R_xie"]},"F_tou",0.085)
	var nearl := await prepare_character("临光","char_148_nearl",{
		"body":[["F_Waist","F_Chest","F_Scarf","F_Scarf_B","F_Skirt"],"F_Waist"],
		"head":[["F_B_Hair","F_B_Hair_B","F_F_Hair","F_Head","F_Headset","F_Eyes","F_Eyebrow","F_Mouth","F_L_Hair","F_L_Hair_B","F_R_Hair","F_R_Hair_B","F_L_Ear","F_R_Ear"],""],
		"left_upper_arm":[["F_L_Arm","F_L_Bag"],"F_L_Arm"],
		"left_forearm":[["F_L_Forearm","F_L_Hand","F_L_Hand Armour","F_L_Finger"],"F_L_Forearm"],
		"right_upper_arm":[["F_R_Arm","F_R_Bag"],"F_R_Arm"],
		"right_forearm":[["F_R_Forearm","F_R_Hand","F_R_Hand Armour","F_R_Finger_1","F_R_Finger_2","F_R_Finger_3","F_R_Finger_4","F_R_Finger_5"],"F_R_Forearm"],
		"left_thigh":[["F_L_Leg"],"F_L_Leg"],"left_calf":[["F_L_Calf"],"bone23"],"left_foot":[["F_L_Foot"],"F_L_Foot"],
		"right_thigh":[["F_R_Leg"],"F_R_Leg"],"right_calf":[["F_R_Calf"],"F_R_Calf"],"right_foot":[["F_R_Foot"],"F_R_Foot"]},"F_Head",0.085)
	await bake_nearl(nearl)
	print("CAPTURE_RESULT=0")
	quit()
