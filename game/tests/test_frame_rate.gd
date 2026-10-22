extends SceneTree
var sim := NinjaSimulation.new()
var digest := HashingContext.new()
var ticks := 0
var measured_seconds := 0.0

func _initialize() -> void:
	sim.load_level({"id": "rate", "episode": 0, "slot": 0, "title": "Rate test", "tiles": "0".repeat(713),
		"entities": [{"type": 5, "params": [300, 566]}, {"type": 11, "params": [740, 550, 720, 550]}]})
	digest.start(HashingContext.HASH_SHA256)

func _physics_process(delta: float) -> bool:
	var bits := 2 if ticks < 120 else 1
	if ticks > 30 and ticks < 110: bits |= 4
	sim.step(bits)
	ticks += 1
	measured_seconds += delta
	digest.update(var_to_bytes([sim.ninja.pos, sim.ninja.velocity, sim.time_left, sim.ninja.alive]))
	if ticks == 360:
		print("FRAME_RATE_RESULT: ", JSON.stringify({"physics_ticks": ticks, "physics_seconds": measured_seconds,
			"trajectory_sha256": digest.finish().hex_encode(), "position": str(sim.ninja.pos), "timer": sim.time_left}))
		quit()
	return false
