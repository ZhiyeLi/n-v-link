extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func fixture(extra: Array = []) -> Dictionary:
	return {"id": "test", "episode": 0, "slot": 0, "title": "Test", "tiles": "0".repeat(713),
		"entities": [{"type": 5, "params": [300, 566]}, {"type": 11, "params": [740, 550, 720, 550]}] + extra}

func settle(sim: NinjaSimulation) -> void:
	for i in range(10): sim.step(0)

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	check(data.levels.size() == 500, "All 500 campaign levels are present")
	var seen_types := {}
	var campaign_sim := NinjaSimulation.new()
	for index in range(data.levels.size()):
		var level: Dictionary = data.levels[index]
		check(int(level.episode) == index / 5 and int(level.slot) == index % 5, "Campaign ordering " + level.id)
		campaign_sim.load_level(level)
		check(campaign_sim.ninja.pos.is_finite(), "Finite spawn " + level.id)
		for e in level.entities: seen_types[int(e.type)] = true
		for i in range(120):
			if not campaign_sim.ninja.alive or campaign_sim.won: break
			campaign_sim.step(2 | (4 if i % 50 < 35 else 0))
		check(campaign_sim.ninja.pos.is_finite(), "Finite simulation " + level.id)
	check(seen_types.size() == 13, "All thirteen object types exercised")
	print("CAMPAIGN: 500 maps loaded and simulated")

	var terrain := NinjaTerrain.new()
	terrain.load_tiles("0".repeat(713))
	check(terrain.solid(Vector2(10, 300)) and not terrain.solid(Vector2(100, 300)), "World borders and interior")
	check(terrain.contact(Vector2(300, 567), 10).normal == Vector2.UP, "Flat floor collision normal")
	check(is_equal_approx(terrain.ray_distance(Vector2(300, 300), Vector2.DOWN), 276), "Raycast stops at world border")
	for id in range(1, 34):
		var shape := NinjaTerrain.make_shape(id)
		check(NinjaTerrain.signed_area(shape) > 0, "Tile winding " + str(id))
		check(not Geometry2D.triangulate_polygon(shape).is_empty(), "Tile triangulation " + str(id))
	var encoded := "0".repeat(713)
	encoded[(10 - 1) * 23 + 19 - 1] = "1"
	encoded[(11 - 1) * 23 + 19 - 1] = "1"
	terrain.load_tiles(encoded)
	check(terrain.solid(Vector2(250, 460)), "Column-major map decoding")
	var seam := terrain.contact(Vector2(264, 448), 10)
	check(not seam.is_empty() and seam.normal.dot(Vector2.UP) > 0.99, "Adjacent tiles have no internal collision wall")

	var sim := NinjaSimulation.new()
	sim.load_level(fixture())
	settle(sim)
	check(sim.ninja.on_floor and absf(sim.ninja.pos.y - 566) < 0.01, "Player settles on floor without sinking")
	var start_y := sim.ninja.pos.y
	sim.step(4)
	check(sim.ninja.velocity.y < -110 and not sim.ninja.on_floor, "Ground jump creates upward impulse")
	var high := sim.ninja.pos.y
	for i in range(130):
		sim.step(4)
		high = minf(high, sim.ninja.pos.y)
	check(start_y - high > 65, "Held jump reaches expected height")
	sim.load_level(fixture())
	settle(sim)
	sim.step(4)
	var tap_high := sim.ninja.pos.y
	for i in range(130):
		sim.step(0)
		tap_high = minf(tap_high, sim.ninja.pos.y)
	check(tap_high - high > 30, "Releasing jump shortens the arc")
	check(sim.ninja.alive, "Ordinary jump landing is safe")

	var acceleration_distances := []
	for multiplier in [0.25, 1.0, 4.0]:
		sim.load_level(fixture())
		sim.acceleration = multiplier
		settle(sim)
		for i in range(60): sim.step(2)
		acceleration_distances.append(sim.ninja.pos.x - 300)
		check(absf(sim.ninja.velocity.x) <= NinjaBody.SPEED + 0.01, "Acceleration preserves max run speed " + str(multiplier))
	check(acceleration_distances[0] < acceleration_distances[1] and acceleration_distances[1] < acceleration_distances[2], "Acceleration setting visibly changes run-up distance")
	print("ACCELERATION_DISTANCES_0.5S: ", acceleration_distances)
	sim.acceleration = 1
	for i in range(60): sim.step(0)
	check(absf(sim.ninja.velocity.x) < 40, "Release produces gradual frictional deceleration")

	sim.load_level(fixture())
	sim.ninja.reset(Vector2(34, 300))
	sim.ninja.near_wall = true
	sim.ninja.wall_normal = Vector2.RIGHT
	sim.step(4 | 2)
	check(sim.ninja.velocity.x > 50 and sim.ninja.velocity.y < -70, "Away wall-jump impulse")
	sim.load_level(fixture())
	sim.ninja.reset(Vector2(300, 200))
	for i in range(360): sim.step(0)
	check(not sim.ninja.alive and sim.ninja.death_reason == "摔落", "Long fall is lethal")

	sim.load_level(fixture([{"type": 0, "params": [300, 566]}]))
	sim.step(0)
	check(sim.gold == 1 and sim.time_left > 91.9, "Gold is collected once and grants two seconds")
	sim.step(0)
	check(sim.gold == 1, "Gold cannot be collected twice")
	sim.load_level(fixture([{"type": 12, "params": [300, 566]}]))
	sim.step(0)
	check(not sim.ninja.alive, "Mine contact kills")
	sim.load_level(fixture(), 42)
	sim.ninja.reset(Vector2(720, 550))
	sim.step(0)
	sim.ninja.reset(Vector2(740, 550))
	sim.step(0)
	check(sim.won and sim.time_left > 41.9, "Exit requires switch and preserves episode time")
	sim.load_level(fixture(), 0.001)
	sim.step(0)
	check(not sim.ninja.alive and sim.time_left == 0, "Countdown expiration kills")

	var saved := NinjaSettings.new(true)
	saved.max_fps = 144
	saved.acceleration = 2.5
	saved.save()
	var persisted = JSON.parse_string(FileAccess.get_file_as_string(saved.path))
	check(persisted.max_fps == 144 and persisted.acceleration == 2.5, "Settings persist on disk")
	saved.max_fps = 0
	saved.apply()
	check(Engine.max_fps == 0, "Unlimited FPS removes engine render cap")
	saved.max_fps = 165
	saved.apply()
	check(Engine.max_fps == 165, "Manual FPS applies to engine")
	var report := {"checks": checks, "failures": failures, "milliseconds": Time.get_ticks_msec() - started,
		"acceleration_run_up_distances": acceleration_distances, "held_jump_height": start_y - high, "tap_jump_height": start_y - tap_high}
	var output := FileAccess.open(ProjectSettings.globalize_path("res://../logs/tests.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("TEST_RESULT: ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
