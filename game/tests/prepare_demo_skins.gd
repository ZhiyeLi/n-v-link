extends SceneTree
var last_render: Dictionary = {}
## Offline preparation of the two requested examples, using setup-pose meshes.
## The game itself imports ordinary images and does not need a Spine runtime.

func _initialize() -> void: call_deferred("run")

func render_group(data: Dictionary, atlas: Texture2D, selected: Array, bone_name: String = "") -> Image:
	var vertices := []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var angle := 0.0
	if not bone_name.is_empty():
		for bone in data.bones:
			if bone.name == bone_name: angle = -Vector2(bone.world[0], -bone.world[1]).angle()
	for a in data.attachments:
		if not selected.is_empty() and not a.name in selected: continue
		var points := PackedVector2Array()
		for p in a.vertices:
			var v := Vector2(p[0], p[1]).rotated(angle)
			points.append(v)
			low = low.min(v)
			high = high.max(v)
		vertices.append({"points": points, "attachment": a})
	var bounds := high - low
	var scale := 460.0 / maxf(bounds.x, bounds.y)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for item in vertices:
		var a: Dictionary = item.attachment
		for i in range(0, a.triangles.size(), 3):
			var poly := Polygon2D.new()
			var points := PackedVector2Array()
			var uv := PackedVector2Array()
			for j in range(3):
				var index := int(a.triangles[i + j])
				points.append((item.points[index] - low - bounds * 0.5) * scale + Vector2(256, 256))
				uv.append(Vector2(a.uv[index][0], a.uv[index][1]))
			poly.polygon = points
			poly.uv = uv
			poly.texture = atlas
			viewport.add_child(poly)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	last_render = {"low": low, "bounds": bounds, "angle": angle, "scale": scale, "used": image.get_used_rect()}
	viewport.queue_free()
	return image

func bone(data: Dictionary, key: String) -> Dictionary:
	for value in data.bones:
		if value.name == key: return value
	return {}

func bone_point(data: Dictionary, key: String) -> Vector2:
	var b := bone(data, key)
	return Vector2(b.world[4], -b.world[5])

func image_anchor(point: Vector2) -> Vector2:
	var pixel: Vector2 = (point.rotated(last_render.angle) - last_render.low - last_render.bounds * 0.5) * last_render.scale + Vector2(256, 256)
	return (pixel - Vector2(last_render.used.position)) / Vector2(last_render.used.size)

func run() -> void:
	var out := ProjectSettings.globalize_path("res://data/demo_skins")
	DirAccess.make_dir_recursive_absolute(out)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../sources/prts/exusiai/setup.json"))
	var atlas := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://../sources/prts/exusiai/char_103_angel.png")))
	var groups := {
		"head": [["F_Back_Hair", "F_L_Hair", "F_Head", "F_Eye", "F_Mouth", "F_Front_Hair_C", "F_Front_Hair_A", "F_Front_Hair_B", "F_Eyebrow", "F_Ring"], ""],
		"body": [["F_Waist", "F_Belt", "F_Hood", "F_Bag"], "F_Waist"],
		"left_upper_arm": [["F_L_Arm"], "F_L_Arm"], "left_forearm": [["F_L_Forearm", "F_L_Hand", "F_L_Fingers"], "F_L_Forearm"],
		"right_upper_arm": [["F_R_Arm"], "F_R_Arm"], "right_forearm": [["F_R_Forearm", "F_R_Hand_2"], "F_R_Forearm"],
		"left_thigh": [["F_L_Leg"], "F_L_Leg"], "left_calf": [["F_L_Calf"], "F_L_Calf"], "left_foot": [["F_L_Foot"], "F_L_Foot"],
		"right_thigh": [["F_R_Leg"], "F_R_Leg"], "right_calf": [["F_R_Calf"], "F_R_Calf"], "right_foot": [["F_R_Foot"], "F_R_Foot"]}
	var manifest := {"slots": {}, "sources": ["https://prts.wiki/w/能天使/spine", "https://prts.wiki/w/源石虫/spine"]}
	var factor := 0.085
	var shoulder := (bone_point(data, "F_L_Arm") + bone_point(data, "F_R_Arm")) * 0.5
	var points := {}
	for part in groups:
		var start := bone_point(data, "F_Head" if part == "head" else groups[part][1])
		var end: Vector2
		if part == "head": end = start + Vector2(20, 0)
		elif part == "body": end = shoulder
		else:
			var b := bone(data, groups[part][1])
			end = start + Vector2(b.world[0], -b.world[1]) * float(b.length)
		points[part] = {"start": start, "end": end, "angle": (end - start).angle()}
	manifest.layout = {"version": 1, "scale": 1.0, "motion": 0.65, "parts": {}, "reference": "PRTS Exusiai setup skeleton / native image anchors"}
	for part in groups:
		var image: Image = await render_group(data, atlas, groups[part][0], groups[part][1])
		var origin := image_anchor(points[part].start)
		var end := image_anchor(points[part].end)
		var offset := Vector2.ZERO
		var parent: String = NinjaRig.PARENTS[part]
		if not parent.is_empty():
			var parent_end: Vector2 = points[parent].start if part.ends_with("thigh") else points[parent].end
			offset = (points[part].start - parent_end).rotated(-points[parent].angle) * factor
		manifest.layout.parts[part] = {"width": last_render.used.size.x / last_render.scale * factor,
			"pivot_x": origin.x, "pivot_y": origin.y, "tip_x": end.x, "tip_y": end.y,
			"offset_x": offset.x, "offset_y": offset.y, "angle": 0.0, "reference_angle": points[part].angle,
			"layer": 8 if part == "head" else (5 if part == "body" else (2 if part.begins_with("left_") else 6))}
		var slot: String = "player_" + part
		var normalized := NinjaSkins.normalize(image, NinjaSkins.canvas_size(slot))
		if normalized == null:
			printerr("Empty demo part: ", part); quit(1); return
		normalized.save_png(out.path_join(slot + ".png"))
		manifest.slots[slot] = slot + ".png"
	var slug: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../sources/prts/slug/setup.json"))
	var slug_atlas := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://../sources/prts/slug/enemy_1007_slime.png")))
	var slug_image: Image = await render_group(slug, slug_atlas, [])
	NinjaSkins.normalize(slug_image, Vector2i(256, 256)).save_png(out.path_join("drone_patrol.png"))
	manifest.slots.drone_patrol = "drone_patrol.png"
	var file := FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	print("PREPARE_CAPTURE_RESULT=0")
	quit()
