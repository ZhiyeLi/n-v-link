extends SceneTree
var failures: Array[String] = []
var checks := 0
var metrics := {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func _initialize() -> void: call_deferred("run")

func fixture(at: Vector2) -> NinjaSimulation:
	var sim := NinjaSimulation.new()
	sim.load_level({"id": "v051", "episode": 0, "slot": 0, "title": "", "tiles": "0".repeat(713), "entities": [{"type": 5, "params": [at.x, at.y]}]})
	return sim

func run() -> void:
	# Early taps, including taps fully released before touching the wall.
	for release_early in [false, true]:
		var sim := fixture(Vector2(40, 300))
		sim.ninja.velocity = Vector2(-100, -120)
		sim.ninja.jumped = true
		var jumped_at := -1
		for tick in range(16):
			sim.step(NinjaInputFrame.LEFT | (NinjaInputFrame.JUMP if tick == 0 or not release_early else 0))
			if sim.ninja.just_jumped:
				jumped_at = tick
				check(sim.ninja.velocity.y < -160, "Early wall press adds to upward momentum")
				check(sim.events.count("jump") == 1, "Buffered contact emits exactly one jump event")
				break
		check(jumped_at > 0 and jumped_at < 12, "Early press fires on arrival, even with previous jump active")
		if release_early: check(not sim.ninja.jumped, "Released buffered tap does not acquire hold gravity")
	# Press exactly on the tick that first makes contact.
	var sim := fixture(Vector2(34.4, 300))
	sim.ninja.velocity = Vector2(-100, -60)
	sim.step(NinjaInputFrame.JUMP | NinjaInputFrame.LEFT)
	check(sim.ninja.just_jumped and sim.ninja.velocity.x > 0, "Contact-tick press fires immediately")
	# A contact can be used for 100ms after departing, but cannot be spent twice.
	for delay in [5, 16]:
		sim = fixture(Vector2(34, 300))
		sim.step(NinjaInputFrame.LEFT)
		check(sim.ninja.near_wall, "Coyote test starts with real wall contact")
		sim.ninja.velocity = Vector2(100, -80)
		for tick in range(delay): sim.step(NinjaInputFrame.RIGHT)
		sim.step(NinjaInputFrame.RIGHT | NinjaInputFrame.JUMP)
		check(sim.ninja.just_jumped == (delay == 5), "Wall grace accepts a late press and rejects an expired one")
		if delay == 5:
			sim.step(NinjaInputFrame.RIGHT)
			sim.step(NinjaInputFrame.RIGHT | NinjaInputFrame.JUMP)
			check(not sim.ninja.just_jumped, "Used grace cannot provide an air double-jump")
	# Holding one press through a whole return to the same wall is not auto-hop.
	sim = fixture(Vector2(34, 300))
	sim.step(NinjaInputFrame.LEFT)
	var count := 0
	for tick in range(100):
		sim.step(NinjaInputFrame.LEFT | NinjaInputFrame.JUMP)
		if sim.ninja.just_jumped: count += 1
	check(count == 1 and sim.ninja.near_wall, "Held jump does not retrigger on recontact")
	# No unlimited airborne buffering; stale inputs and level reset are cleared.
	sim = fixture(Vector2(100, 300))
	sim.step(NinjaInputFrame.JUMP)
	for tick in range(20): sim.step(0)
	sim.ninja.pos = Vector2(34, 300)
	sim.step(NinjaInputFrame.LEFT)
	check(not sim.ninja.just_jumped, "Expired buffered press cannot jump at a later wall")
	sim.step(NinjaInputFrame.JUMP_PRESS)
	check(sim.ninja.just_jumped, "Explicit input edge triggers even without sampled hold")
	sim.ninja.reset(Vector2(100, 300))
	check(sim.ninja.jump_buffer == 0 and sim.ninja.wall_grace == 0, "Level reset clears assists")
	# Real narrow corridor; press before each impact instead of frame-perfect contact.
	sim = fixture(Vector2(300, 540))
	var tiles := ""
	for x in range(1, 32):
		for y in range(1, 24): tiles += "1" if x in [11, 13] else "0"
	sim.terrain.load_tiles(tiles)
	sim.ninja.velocity = Vector2(-60, -80)
	var direction := -1
	var armed := true
	count = 0
	var peak := 0.0
	for tick in range(200):
		var bits := NinjaInputFrame.LEFT if direction < 0 else NinjaInputFrame.RIGHT
		if armed:
			bits |= NinjaInputFrame.JUMP
			armed = false
		sim.step(bits)
		if sim.ninja.just_jumped:
			count += 1
			direction = int(sim.ninja.jump_wall_normal.x)
			armed = true
		peak = maxf(peak, -sim.ninja.velocity.y)
		if sim.ninja.pos.y < 80: break
	check(count >= 6 and peak > sim.ninja.max_speed, "Early taps chain across alternating walls and build speed")
	metrics.early_tap_wall_jumps = count
	metrics.peak_upward_speed = peak
	# Key down + up between simulation ticks still leaves one sampled press.
	NinjaBindings.install(NinjaBindings.DEFAULTS)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	NinjaInputFrame.observe(event)
	var bits := NinjaInputFrame.sample()
	check(bits & NinjaInputFrame.JUMP_PRESS != 0 and bits & NinjaInputFrame.JUMP == 0, "Fast tap edge survives even when hold sampling sees key up")
	check(NinjaInputFrame.sample() & NinjaInputFrame.JUMP_PRESS == 0, "Input edge consumed once")
	NinjaInputFrame.observe(event)
	NinjaBindings.release_actions()
	check(NinjaInputFrame.sample() & NinjaInputFrame.JUMP_PRESS == 0, "Pause/focus/rebind release clears pending press")
	# Full gait, not six stills: cycle seam, angular continuity and attached joints.
	var skins := NinjaSkins.new(ProjectSettings.globalize_path("res://.local/v051"))
	skins.reset_all()
	check(skins.install_demo().ok, "Demo installs in isolated folder")
	var rig := NinjaRig.new()
	root.add_child(rig)
	skins.apply_rig(rig)
	var previous := {}
	var max_step := 0.0
	var min_stride := INF
	var max_stride := -INF
	for frame in range(721):
		var pose := NinjaAnimation.make_pose("run", frame * TAU / 720, 216, 0, 1)
		rig.set_pose(pose, 1, "run")
		var stride: float = rig.display_bones.left_calf.end.x - rig.display_bones.right_calf.end.x
		min_stride = minf(min_stride, stride)
		max_stride = maxf(max_stride, stride)
		for key in NinjaRig.PARTS:
			var bone: Dictionary = rig.display_bones[key]
			if previous.has(key):
				max_step = maxf(max_step, absf(angle_difference(previous[key], bone.angle)))
			previous[key] = bone.angle
			if key in ["left_forearm", "right_forearm", "left_calf", "right_calf", "left_foot", "right_foot"]:
				check(bone.start.distance_to(rig.display_bones[NinjaRig.PARENTS[key]].end) < 0.001, "Running joints stay connected throughout the full cycle")
		for side in ["left", "right"]:
			var thigh: Dictionary = rig.display_bones[side + "_thigh"]
			var calf: Dictionary = rig.display_bones[side + "_calf"]
			var arm: Dictionary = rig.display_bones[side + "_upper_arm"]
			var forearm: Dictionary = rig.display_bones[side + "_forearm"]
			check((thigh.end - thigh.start).cross(calf.end - calf.start) > 0, "Knee bends forward throughout run, never inverts")
			check((arm.end - arm.start).cross(forearm.end - forearm.start) < 0, "Elbow bends consistently throughout run, never inverts")
	check(min_stride < -4 and max_stride > 4, "Both legs alternate front/back through the run")
	check(max_step < deg_to_rad(15), "Run does not snap or reverse at angle wraps or cycle seam")
	metrics.max_run_step_degrees = rad_to_deg(max_step)
	metrics.run_stride_range = [min_stride, max_stride]
	rig.queue_free()
	await process_frame
	var report := {"checks": checks, "failures": failures, "metrics": metrics}
	FileAccess.open(ProjectSettings.globalize_path("res://../logs/v051-tests.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("V051_TEST_RESULT: ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
