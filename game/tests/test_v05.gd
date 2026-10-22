extends SceneTree
var failures: Array[String] = []
var checks := 0
var metrics := {}

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); printerr("FAIL: ", text)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sim := NinjaSimulation.new()
	var encoded := ""
	for x in range(1, 32):
		for y in range(1, 24): encoded += "1" if x in [11, 13] else "0"
	sim.load_level({"id": "chimney", "episode": 0, "slot": 0, "title": "", "tiles": encoded, "entities": [{"type": 5, "params": [298.001, 540]}]})
	sim.ninja.velocity = Vector2(-60, -100)
	sim.step(NinjaInputFrame.LEFT)
	check(sim.ninja.near_wall and sim.ninja.velocity.y < -97, "Ascending wall contact preserves upward momentum")
	var peak := 0.0
	var jumps := 0
	var last_side := 0.0
	var jump_velocities := []
	for i in range(240):
		var axis: int = NinjaInputFrame.RIGHT if last_side >= 0 else NinjaInputFrame.LEFT
		if sim.ninja.near_wall and not sim.ninja.last_jump and sim.ninja.wall_normal.x != last_side:
			last_side = sim.ninja.wall_normal.x
			axis = NinjaInputFrame.RIGHT if last_side > 0 else NinjaInputFrame.LEFT
			axis |= NinjaInputFrame.JUMP
		sim.step(axis)
		if sim.ninja.just_jumped:
			jumps += 1
			jump_velocities.append(sim.ninja.velocity.y)
		peak = maxf(peak, -sim.ninja.velocity.y)
		if sim.ninja.pos.y < 80: break
	check(jumps >= 4, "Actual alternating terrain contacts permit repeated wall jumps")
	check(peak > sim.ninja.max_speed, "Chained wall jumps can exceed the horizontal run cap in upward speed")
	metrics.wall_jumps = jumps
	metrics.wall_jump_vertical_speeds = jump_velocities
	metrics.peak_upward_speed = peak
	var camera := NinjaMapCamera.new()
	camera.configure({"zoom": 2, "snap": true})
	var rect := camera.update(0.016, Vector2(400, 300))
	check(rect.size.is_equal_approx(Vector2(396, 300)), "2x renders only half the map dimensions")
	check((camera.transform_for(rect) * rect.get_center()).is_equal_approx(Vector2(396, 300)), "Map center maps to viewport center")
	for target in [Vector2.ZERO, Vector2(792, 600), Vector2(400, 300)]:
		camera.configure({"snap": true})
		rect = camera.update(0.016, target)
		check(Rect2(Vector2.ZERO, Vector2(792, 600)).encloses(rect), "Camera stays inside map edges")
	camera.configure({"mode": "fixed", "center": Vector2(400, 200), "snap": true})
	check(camera.update(1, Vector2(700, 500)).get_center().is_equal_approx(Vector2(400, 200)), "Fixed camera ignores player changes")
	camera.targets = [Vector2(100, 150), Vector2(650, 450)]
	camera.configure({"mode": "group", "zoom": 4, "snap": true})
	rect = camera.update(1, Vector2.ZERO)
	for target in camera.targets: check(rect.has_point(target), "Group policy includes both players")
	camera.targets = [Vector2(34, 34), Vector2(758, 566)]
	rect = camera.update(0.001, Vector2.ZERO)
	for target in camera.targets: check(rect.has_point(target), "Moving targets at opposite corners stay visible during transition")
	camera.provider = func(_context: Dictionary): return {"center": Vector2(400, 300), "zoom": 3}
	camera.configure({"mode": "custom", "snap": true})
	check(camera.update(1, Vector2.ZERO).size.is_equal_approx(Vector2(264, 200)), "Runtime custom provider controls view dimensions")
	var skins := NinjaSkins.new(ProjectSettings.globalize_path("res://.local/v05"))
	skins.reset_all()
	check(skins.install_demo().ok, "Calibrated demo installs")
	var rig := NinjaRig.new()
	root.add_child(rig)
	for scale in [0.5, 1.0, 1.8]:
		skins.layout.scale = scale
		skins.apply_rig(rig)
		for state in ["run", "rise", "fall", "wall_climb", "wall_slide", "wall_jump"]:
			rig.set_pose(NinjaAnimation.make_pose(state, 0.8, 216, -50, 1), 1, state)
			for key in rig.parts:
				var part: NinjaPart = rig.parts[key]
				var dimensions := NinjaRigLayout.image_size(part.image_layout, part.texture_region, scale)
				check(absf(dimensions.x / dimensions.y - part.texture_region.size.x / part.texture_region.size.y) < 0.00001, "Short and tall models preserve every image's aspect ratio")
				check(part.global_transform.is_finite(), "Calibrated transforms remain finite")
			for key in ["left_forearm", "right_forearm", "left_calf", "right_calf", "left_foot", "right_foot"]:
				var parent: String = NinjaRig.PARENTS[key]
				check(rig.display_bones[key].start.distance_to(rig.display_bones[parent].end) < 0.04, "Calibrated adjacent joints remain attached across sizes and poses")
	skins.set_layout_value("left_calf", "pivot_x", 0.35)
	check(is_equal_approx(NinjaSkins.new(ProjectSettings.globalize_path("res://.local/v05")).layout.parts.left_calf.pivot_x, 0.35), "Edited anchors persist across reload")
	var view = load("res://view/world_view.gd").new()
	view.preview_only = true
	root.add_child(view)
	for slot in NinjaSkins.ENTITY_SLOTS:
		view.preview_entity(slot)
		check(view.visible and view.sim.entities.size() == 1, "Every default entity uses the real world renderer: " + slot)
	view.queue_free()
	rig.queue_free()
	await process_frame
	var report := {"checks": checks, "failures": failures, "metrics": metrics}
	FileAccess.open(ProjectSettings.globalize_path("res://../logs/v05-tests.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("V05_TEST_RESULT: ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
