extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func fixture(extra: Array = []) -> Dictionary:
	return {"id": "controls", "episode": 0, "slot": 0, "title": "Controls", "tiles": "0".repeat(713),
		"entities": [{"type": 5, "params": [300, 566]}, {"type": 11, "params": [740, 550, 720, 550]}] + extra}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim := NinjaSimulation.new()
	var speeds := []
	var tap_distances := []
	for multiplier in [0.25, 0.5, 1.0, 2.0, 4.0]:
		for airborne in [false, true]:
			sim.load_level(fixture())
			sim.acceleration = multiplier
			for i in range(1200):
				# A treadmill fixture removes wall impacts, not velocity or drag.
				sim.ninja.pos = Vector2(300, 300 if airborne else 566)
				sim.ninja.on_floor = not airborne
				sim.ninja.velocity.y = 0
				sim.step(NinjaInputFrame.RIGHT)
			check(absf(sim.ninja.velocity.x - NinjaBody.SPEED) < 0.01, "Identical terminal speed at " + str(multiplier) + (" in air" if airborne else " on ground"))
			speeds.append({"acceleration": multiplier, "air": airborne, "speed": sim.ninja.velocity.x})
		sim.load_level(fixture())
		for i in range(10): sim.step(0)
		for i in range(12): sim.step(NinjaInputFrame.RIGHT)
		for i in range(240): sim.step(0)
		var distance := sim.ninja.pos.x - 300
		tap_distances.append(distance)
		check(distance > 0 and distance < 30, "100 ms tap cannot cross map at " + str(multiplier))
		check(absf(sim.ninja.velocity.x) < 0.05, "Released input settles at " + str(multiplier))

	sim.load_level(fixture())
	for i in range(10): sim.step(0)
	sim.step(NinjaInputFrame.RIGHT)
	sim.step(NinjaInputFrame.LEFT | NinjaInputFrame.RIGHT)
	check(sim.ninja.facing == -1, "Last pressed direction wins when both keys held")
	sim.step(0)
	check(sim.ninja.facing == -1, "Releasing keys preserves facing")
	sim.ninja.velocity = Vector2(100, 0)
	sim.step(0)
	check(sim.ninja.facing == -1, "Momentum cannot reverse facing")
	sim.step(NinjaInputFrame.FACE_RIGHT)
	check(sim.ninja.facing == 1, "Explicit last-input facing bit is respected")

	sim.load_level(fixture())
	sim.ninja.reset(Vector2(34, 300))
	sim.ninja.velocity = Vector2(0, -50)
	sim.step(NinjaInputFrame.LEFT)
	check(sim.ninja.motion == NinjaBody.Motion.WALLCLIMBING, "Rising against wall selects climbing animation")
	sim.ninja.velocity.y = 50
	sim.step(NinjaInputFrame.LEFT)
	check(sim.ninja.motion == NinjaBody.Motion.WALLSLIDING, "Descending against wall selects slide animation")
	sim.step(NinjaInputFrame.LEFT | NinjaInputFrame.JUMP)
	check(sim.ninja.motion == NinjaBody.Motion.WALLJUMPING, "Wall jump has distinct animation state")

	sim.load_level(fixture([{"type": 1, "params": [300, 566]}]))
	var fastest := 0.0
	for i in range(240):
		sim.step(0)
		fastest = maxf(fastest, sim.ninja.velocity.length())
	check(fastest < 160, "Bounce-block depenetration does not create an unbounded impulse")

	var rig := NinjaRig.new()
	root.add_child(rig)
	check(rig.parts.size() == 12, "Twelve separately addressable body parts")
	check(rig.parts.left_forearm.get_parent() == rig.parts.left_upper_arm, "Forearm inherits upper-arm transform")
	check(rig.parts.left_foot.get_parent() == rig.parts.left_calf, "Foot inherits calf transform")
	var poses := {}
	for stance in ["idle", "run", "skid", "takeoff", "rise", "fall", "wall_climb", "wall_slide", "wall_jump"]:
		var pose := NinjaRig.make_pose(stance, 0.6, 100, 70, 1)
		poses[stance] = pose
		rig.set_pose(pose)
		for part_name in NinjaRig.PARTS:
			check(rig.parts[part_name].position.is_finite() and is_finite(rig.parts[part_name].rotation), "Finite articulated pose " + stance + "/" + part_name)
		for side in ["left", "right"]:
			check(absf(pose.shoulder.distance_to(pose[side + "_elbow"]) - 3.9) < 0.01, "Constant upper-arm length " + stance)
			check(absf(pose.hip.distance_to(pose[side + "_knee"]) - NinjaAnimation.LEG) < 0.01, "Constant thigh length " + stance)
	check(poses.wall_climb != poses.wall_slide and poses.rise != poses.fall and poses.takeoff != poses.wall_jump, "Wall, jump and falling poses are distinct")
	var n := NinjaBody.new()
	n.facing = -1
	rig.animate(n, 1)
	check(rig.scale.x == -1, "Whole articulated character mirrors from input facing")
	rig.queue_free()
	await process_frame
	var report := {"checks": checks, "failures": failures, "terminal_speeds": speeds,
		"tap_100ms_total_distance": tap_distances, "bounce_overlap_peak_speed": fastest}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../logs/controls-tests.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CONTROLS_TEST_RESULT: ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
