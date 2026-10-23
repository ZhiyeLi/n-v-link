extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr(message)

func fixture(at: Vector2 = Vector2(300,300), extra: Array = []) -> Dictionary:
	return {"id":"v052", "episode":0, "slot":0, "title":"", "tiles":"0".repeat(713),
		"entities":[{"type":5,"params":[at.x,at.y]}] + extra}

func press(main: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	main._unhandled_key_input(event)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	check(NinjaBody.JUMP_BUFFER == 0.12 and NinjaBody.WALL_GRACE == 0.10, "0.5.1 control windows restored")
	var sim := NinjaSimulation.new()
	sim.load_level(fixture(Vector2(35.5,300)))
	sim.step(NinjaInputFrame.JUMP_PRESS)
	check(not sim.ninja.just_jumped, "Removed 0.5.2 spatial wall assistance")
	sim.load_level(fixture())
	sim.ninja.wall_jump = true
	sim.ninja.velocity = Vector2(60,-100)
	for i in range(9): sim.step(0)
	check(sim.ninja.pose_name() == "wall_jump", "Wall-jump pose lasts approximately 83ms")
	for i in range(2): sim.step(0)
	check(sim.ninja.pose_name() == "rise", "Wall-jump pose transitions to ordinary jumping at one-third duration")
	sim.suicide_rng.seed = 12345
	var explosive_count := 0
	for i in range(200):
		sim.load_level(fixture())
		sim.time_left = 54.3
		sim.gold = 3
		sim.tick = 42
		sim.suicide()
		if sim.ragdoll.exploded: explosive_count += 1
		check(not sim.ninja.alive and sim.ragdoll.active and sim.ragdoll.bones.size() == 12, "Suicide enters a complete ragdoll")
		check(sim.time_left == 54.3 and sim.gold == 3 and sim.tick == 42, "Suicide preserves the current level instead of resetting it")
		var particles := sim.death_fx.drops.size()
		sim.suicide()
		check(sim.death_fx.drops.size() == particles and sim.events.count("death") == 1, "Repeated suicide cannot restart or duplicate death")
	check(explosive_count > 75 and explosive_count < 125, "Fixed-seed sample covers both 50/50 suicide branches")
	for type in [4,6,8]:
		var params: Array = [300,300,0] if type == 4 else ([300,300,0,0,0,0] if type == 6 else [300,300,1])
		sim.load_level(fixture(Vector2(300,318) if type == 8 else Vector2(300,300), [{"type":type,"params":params}]))
		sim.step(0)
		check(not sim.ninja.alive and sim.ninja.death_kind == NinjaBody.DeathKind.ELECTRIC, "Enemy collision uses electric death: " + str(type))
		check(sim.death_fx.arcs.size() == 6 and not sim.ragdoll.exploded, "Electric death creates six arcs and an intact ragdoll")
		for i in range(60): sim.step(0)
		check(sim.death_fx.arcs.is_empty() and sim.ragdoll.age > 0.4, "Electric flash expires while corpse continues moving")
	var explosive_drops := 0
	for type in [12,10]:
		sim.load_level(fixture(Vector2(300,300), [{"type":type,"params":[300,300]}]))
		if type == 10:
			var rocket: Dictionary = sim.entities[0]
			rocket.state = 1; rocket.speed = 100.0; rocket.thrust = 160.0
		sim.step(0)
		explosive_drops = sim.death_fx.drops.size()
		check(sim.ragdoll.exploded and explosive_drops >= 80, "Mine/rocket creates dismemberment and a large red spray")
	sim.load_level(fixture(Vector2(300,565)))
	sim.ninja.velocity = Vector2(20,350)
	sim.step(0)
	check(sim.ninja.death_kind == NinjaBody.DeathKind.FALL and not sim.ragdoll.exploded, "Fatal fall keeps limbs connected")
	check(sim.death_fx.drops.size() == 12 and sim.death_fx.drops.size() < explosive_drops / 4, "Fall creates much less blood than explosion")
	for i in range(300): sim.step(0)
	check(sim.death_fx.drops.is_empty() and not sim.death_fx.stains.is_empty(), "Blood falls, hits terrain, and leaves temporary splashes")
	sim.load_level(fixture())
	check(sim.death_fx.stains.is_empty() and sim.death_fx.drops.is_empty(), "Retry clears death particles and stains")
	var main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = ProjectSettings.globalize_path("res://.local/v052-settings.json")
	root.add_child(main)
	main.set_physics_process(false)
	main.start_episode(0)
	main.sim.time_left = 62
	press(main, KEY_R)
	check(main.state == "dead" and main.sim.time_left == 62 and main.sim.ragdoll.active, "Default R kills immediately without resetting the map")
	press(main, KEY_R)
	check(main.state == "dead", "R does not skip the death animation")
	for i in range(30): main._physics_process(NinjaSimulation.DT)
	check(main.sim.ragdoll.age > 0.2 and not main.world.paused, "Death banner leaves main scene animating")
	press(main, KEY_ENTER)
	check(main.state == "playing" and main.sim.ninja.alive and main.sim.tick == 0, "Confirm key retries after death")
	main.settings.bindings.retry = [KEY_X,0,0]
	NinjaBindings.install(main.settings.bindings)
	press(main, KEY_R)
	check(main.state == "playing", "Removed suicide binding no longer acts")
	main.show_pause()
	press(main, KEY_X)
	check(main.state == "dead" and not main.world.paused, "Remapped suicide works from pause and resumes corpse rendering")
	main.free()
	var report := {"checks":checks,"failures":failures,"suicide_explosive_count_of_200":explosive_count}
	FileAccess.open(ProjectSettings.globalize_path("res://../logs/v052-tests.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V052_TEST_RESULT: ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
