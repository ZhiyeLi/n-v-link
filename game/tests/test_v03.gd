extends SceneTree
var failures: Array[String] = []
var checks := 0
var metrics := {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func fixture(extra: Array = []) -> Dictionary:
	return {"id": "v03", "episode": 0, "slot": 0, "title": "Regression", "tiles": "0".repeat(713),
		"entities": [{"type": 5, "params": [300, 566]}] + extra}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sim := NinjaSimulation.new()
	sim.load_level(fixture())
	for i in range(20): sim.step(0)
	var run_ticks := 0
	var samples := {}
	for i in range(220):
		sim.step(NinjaInputFrame.RIGHT)
		if i > 5 and sim.ninja.motion == NinjaBody.Motion.RUNNING: run_ticks += 1
		if i % 15 == 0: samples[str(sim.ninja.visual_pose().left_ankle)] = true
	check(run_ticks == 214, "Continuous floor movement stays in RUN, without air/idle flicker")
	check(samples.size() > 10 and sim.ninja.run_distance > 100, "Run pose advances through a distance-driven cycle")
	var rig := NinjaRig.new()
	root.add_child(rig)
	for part in rig.parts.values():
		check(part.z_index >= 0, "No articulated body part renders behind the world background")
	var expected: Dictionary = sim.ninja.visual_pose()
	for fps in [30, 60, 144, 1000]:
		rig.animate(sim.ninja, 1.0 / fps)
		check(rig.joints == expected, "Render FPS does not advance animation state at " + str(fps))
	var rise := NinjaAnimation.make_pose("air", 0, 80, -80, 1)
	var apex := NinjaAnimation.make_pose("air", 0, 80, 0, 1)
	var fall := NinjaAnimation.make_pose("air", 0, 80, 120, 1)
	check(rise.left_ankle.distance_to(apex.left_ankle) > 2 and apex.left_hand.distance_to(fall.left_hand) > 2, "Air silhouette changes continuously through ascent, apex and descent")
	sim.load_level(fixture())
	sim.ninja.reset(Vector2(35, 250))
	sim.ninja.velocity = Vector2(-144, 180)
	sim.step(NinjaInputFrame.LEFT)
	check(sim.ninja.velocity.y < 140 and absf(sim.ninja.velocity.x) < 1, "First wall impact immediately damps tangent and normal motion")
	for i in range(120): sim.step(NinjaInputFrame.LEFT)
	metrics.wall_slide_speed = sim.ninja.velocity.y
	check(sim.ninja.motion == NinjaBody.Motion.WALLSLIDING and sim.ninja.velocity.y < 20, "Held wall slide has stronger friction and a low terminal speed")
	sim.step(NinjaInputFrame.JUMP | NinjaInputFrame.RIGHT)
	check(sim.ninja.motion == NinjaBody.Motion.WALLJUMPING and sim.ninja.velocity.x > 0, "Wall push-off leaves the wall with its own pose")
	for i in range(40): sim.step(NinjaInputFrame.RIGHT)
	check(sim.ninja.motion != NinjaBody.Motion.WALLJUMPING, "Released jump cannot leave wall-jump animation stuck forever")

	for scout in [0, 1]:
		sim.load_level(fixture([{"type": 6, "params": [108, 108, 2, scout, 0, 0]}]))
		sim.ninja.pos = Vector2(348, 109)
		var e: Dictionary = sim.entities[0]
		sim.update_drone(e)
		check(e.chasing == (scout == 1), "Only scout acquires aligned player")
		check(is_equal_approx(e.target.x, 756 if scout == 1 else 132), "Scout commits to corridor end; patrol keeps one-cell goal")
		metrics["scout_speed" if scout == 1 else "patrol_speed"] = (e.pos.x - 108) / NinjaSimulation.DT
		if scout == 1:
			sim.ninja.pos = Vector2(400, 300)
			sim.update_drone(e)
			check(e.chasing and e.target.x == 756, "Scout continues committed pursuit when player leaves the row")
	check(absf(metrics.scout_speed / metrics.patrol_speed - 2) < 0.001, "Pursuit speed is twice patrol speed")
	sim.load_level(fixture([{"type": 6, "params": [108, 108, 2, 1, 0, 2]}]))
	sim.ninja.pos = Vector2(348, 108)
	sim.update_drone(sim.entities[0])
	check(not sim.entities[0].chasing, "Scout cannot reverse direction to acquire a target behind it")
	sim.load_level(fixture([{"type": 6, "params": [108, 108, 2, 1, 0, 0]}]))
	sim.ninja.pos = Vector2(348, 108)
	var tiles: String = sim.level.tiles
	# Terrain encoding is column-major for its 31 by 23 interior cells.
	tiles[6 * 23 + 3] = "1"
	sim.terrain.load_tiles(tiles)
	sim.update_drone(sim.entities[0])
	check(not sim.entities[0].chasing, "Terrain blocks scout acquisition")

	for explosive in [false, true]:
		sim.load_level(fixture([{"type": 6, "params": [108, 108, 2, 0, 0, 0]}]))
		sim.ninja.reset(Vector2(300, 500))
		sim.ninja.velocity = Vector2(80, 0)
		sim.step(NinjaInputFrame.RIGHT)
		var pose := sim.ninja.visual_pose()
		sim.ninja.kill("fixture", explosive, sim.ninja.pos - Vector2(3, 0))
		sim.finish_death()
		check(sim.ragdoll.exploded == explosive and sim.ragdoll.bones.size() == 12, "Death retains every renderable body part")
		check(sim.ragdoll.points.shoulder.pos.distance_to(sim.ninja.pos + pose.shoulder) < 0.01, "Ragdoll starts at the current animated shoulder")
		check((sim.ragdoll.bones.left_upper_arm[0] == "shoulder") == (not explosive), "Explosion disconnects limb roots; ordinary death keeps shoulder joint")
		var before: Vector2 = sim.entities[0].pos
		var frozen_time := sim.time_left
		var max_error := 0.0
		for i in range(360):
			sim.step(0)
			for point in sim.ragdoll.points.values():
				check((point.pos as Vector2).is_finite(), "Corpse physics remains finite")
			for stick in sim.ragdoll.sticks:
				var length: float = sim.ragdoll.points[stick.a].pos.distance_to(sim.ragdoll.points[stick.b].pos)
				max_error = maxf(max_error, absf(length - stick.length))
		check(max_error < 1.5, "Ragdoll segment lengths stay bounded during impact and settling")
		check(sim.entities[0].pos.distance_to(before) > 40 and sim.ragdoll.age > 2.9, "World and ragdoll continue simulating after death")
		check(sim.time_left == frozen_time and sim.gold == 0 and not sim.won, "Dead player cannot collect, win or consume level time")
		metrics["exploded_max_constraint_error" if explosive else "intact_max_constraint_error"] = max_error
		if not explosive:
			sim.ragdoll.explode(sim.ragdoll.points.hip.pos, sim.rng)
			check(sim.ragdoll.bones.right_thigh[0] != "hip", "A later explosion can detach an intact corpse")
	sim.load_level(fixture([{"type": 12, "params": [300, 566]}]))
	sim.step(0)
	check(sim.ragdoll.exploded and not sim.entities[0].active, "Mine causes explosive death and is consumed")
	sim.load_level(fixture([{"type": 10, "params": [400, 300]}]))
	sim.ninja.pos = Vector2(300, 300)
	var rocket: Dictionary = sim.entities[0]
	rocket.state = 1; rocket.pos = Vector2(300, 300); rocket.dir = Vector2.RIGHT; rocket.speed = 100.0; rocket.thrust = 160.0
	sim.step(0)
	check(sim.ragdoll.exploded and rocket.state == 0, "Rocket collision separates limbs and removes active missile")
	rig.queue_free()
	await process_frame
	var report := {"checks": checks, "failures": failures, "metrics": metrics}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../logs/v03-regressions.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("V03_TEST_RESULT: ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
