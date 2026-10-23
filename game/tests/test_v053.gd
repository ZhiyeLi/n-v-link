extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr(message)

func fixture() -> Dictionary:
	return {"id":"v053", "episode":0, "slot":0, "tiles":"0".repeat(713),
		"entities":[{"type":5,"params":[348,108]}, {"type":6,"params":[108,108,2,0,1,0]}]}

func acquire(sim: NinjaSimulation) -> Dictionary:
	sim.load_level(fixture())
	var e: Dictionary = sim.entities[0]
	sim.update_drone(e)
	return e

func advance(sim: NinjaSimulation, e: Dictionary, ticks: int) -> void:
	for i in range(ticks): sim.update_drone(e)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sim := NinjaSimulation.new()
	var e := acquire(sim)
	var origin: Vector2 = e.pos
	var direction: Vector2 = e.shot
	var endpoint := sim.laser_beam_end(e)
	check(e.state == 2 and sim.ninja.alive, "Acquisition begins harmless charge")
	advance(sim, e, 89)
	check(e.state == 2 and sim.ninja.alive, "Standing on the warning line is safe for the full prefire interval")
	sim.update_drone(e)
	check(e.state == 3 and not sim.ninja.alive, "Beam becomes lethal at 0.75 seconds, not before")
	sim.finish_death()
	check(e.state == 0, "Death ends the laser attack")

	e = acquire(sim)
	origin = e.pos
	direction = e.shot
	endpoint = sim.laser_beam_end(e)
	sim.ninja.pos = Vector2(348,220)
	advance(sim, e, 90)
	check(e.state == 3 and sim.ninja.alive, "Moving off the warning line before firing avoids the shot")
	check(e.pos == origin and e.shot == direction and sim.laser_beam_end(e) == endpoint, "Charge locks both drone position and ray instead of tracking the player")
	advance(sim, e, 239)
	check(e.state == 3 and sim.ninja.alive and e.pos == origin, "Laser remains stationary and active for almost two seconds")
	sim.update_drone(e)
	check(e.state == 4 and sim.ninja.alive, "Laser switches off at two seconds")
	sim.ninja.pos = Vector2(348,108)
	advance(sim, e, 119)
	check(e.state == 4 and e.pos == origin and sim.ninja.alive, "Postfire cooldown is stationary and harmless")
	sim.update_drone(e)
	check(e.state == 0 and e.pos == origin, "Cooldown lasts exactly one second")
	sim.ninja.pos = Vector2(348,220)
	sim.update_drone(e)
	check(e.pos != origin and e.state == 2 and e.shot != direction, "Patrol resumes and next acquisition locks a new direction")

	e = acquire(sim)
	sim.ninja.pos = Vector2(348,220)
	advance(sim, e, 90 + 180)
	sim.ninja.pos = Vector2(348,108)
	sim.update_drone(e)
	check(not sim.ninja.alive, "Crossing the beam late in its two-second lifetime remains lethal")

	e = acquire(sim)
	var tiles: String = sim.level.tiles
	tiles[(10-1)*23+4-1] = "1"
	sim.terrain.load_tiles(tiles)
	advance(sim, e, 90)
	check(sim.ninja.alive and absf(sim.laser_beam_end(e).x - 240) < 0.01, "Wall appearing during charge clips both damage and visible beam")
	sim.load_level(fixture())
	sim.terrain.load_tiles(tiles)
	e = sim.entities[0]
	advance(sim, e, 30)
	check(e.state == 0, "Drone cannot acquire through terrain")

	e = acquire(sim)
	var door := {"type":9, "open":false, "pos":Vector2(240,108), "dir":Vector2.RIGHT}
	sim.entities.append(door)
	advance(sim, e, 90)
	check(sim.ninja.alive and absf(sim.laser_beam_end(e).x - 240) < 0.01, "Closed door clips the visible beam and blocks damage")
	door.open = true
	sim.update_drone(e)
	check(not sim.ninja.alive, "Opening a door exposes the existing locked ray")

	e = acquire(sim)
	sim.ninja.pos = Vector2(348,220)
	advance(sim, e, 100)
	sim.load_level(fixture())
	check(sim.entities[0].state == 0 and sim.entities[0].beam_length == 0.0, "Retry clears prior beam state")
	# Run the full simulation, including body physics, after a visible warning.
	sim.step(0)
	var shot: Vector2 = sim.entities[0].shot
	for i in range(200): sim.step(NinjaInputFrame.RIGHT)
	check(sim.ninja.alive and sim.entities[0].state == 3 and sim.entities[0].shot == shot, "Full simulation lets a moving player dodge and keeps the active ray locked")
	print("V053_TEST_RESULT: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
