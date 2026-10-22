class_name NinjaSimulation
extends RefCounted
## The simulation consumes timestamp-free input bits. Rendering never advances it.
## Future replay metadata must include version, rate, map hash, seed and acceleration.
const VERSION := "n14-port-0.5.1"
const FLOOR_GUARD_SPEED := 12.0 * (3.0 / 7.0) * 40.0
const RATE := 120
const DT := 1.0 / RATE
const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
var terrain := NinjaTerrain.new()
var ninja := NinjaBody.new()
var entities: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var events: Array[String] = []
var rng := RandomNumberGenerator.new()
var level: Dictionary
var tick := 0
var time_left := 90.0
var start_time := 90.0
var elapsed := 0.0
var gold := 0
var total_gold := 0
var won := false
var acceleration := 1.0
var ragdoll := NinjaRagdoll.new()
var effects: Array[Dictionary] = []

func configuration() -> Dictionary:
	return {"simulation_version": VERSION, "physics_rate": RATE,
		"input_schema": NinjaInputFrame.SCHEMA_VERSION, "acceleration": acceleration, "max_speed": ninja.max_speed,
		"level_id": level.get("id", ""), "level_sha256": level.get("raw_sha256", ""),
		"initial_seed": int(level.get("episode", 0)) * 5 + int(level.get("slot", 0)) + 1}

func load_level(data: Dictionary, seconds: float = 90.0) -> void:
	level = data
	terrain.load_tiles(data.tiles)
	entities.clear()
	bullets.clear()
	ragdoll = NinjaRagdoll.new()
	effects.clear()
	events.clear()
	tick = 0
	elapsed = 0
	time_left = seconds
	start_time = seconds
	gold = 0
	total_gold = 0
	won = false
	rng.seed = int(data.episode) * 5 + int(data.slot) + 1
	for definition in data.entities:
		var p: Array = definition.params
		var type := int(definition.type)
		var pos := Vector2(p[0], p[1])
		if type == 5:
			ninja.reset(pos)
			continue
		var e := {"type": type, "p": p, "pos": pos, "previous": pos, "home": pos,
			"active": true, "timer": 0.0, "state": 0, "velocity": Vector2.ZERO,
			"dir": Vector2.RIGHT, "target": pos, "aim": pos, "shot": Vector2.ZERO,
			"flash": 0.0, "cooldown": 0.0, "open": false, "turn": false}
		match type:
			0: total_gold += 1
			2: e.dir = Vector2(p[2], p[3])
			4:
				e.dir = DIRECTIONS[int(p[2]) % 4]
				e.pos.y = floorf(pos.y / 24) * 24 + 18
			6:
				e.dir = DIRECTIONS[int(p[5]) % 4]
				e.pos = (pos / 24).floor() * 24 + Vector2(12, 12)
				e.target = e.pos
				e.chasing = false
				e.surface_grab = -1
				e.ai_ticks = 0
			7, 8: e.dir = DIRECTIONS[int(p[2]) % 4]
			9:
				e.trigger = pos
				e.pos = Vector2(p[4] + p[7] + 0.5, p[5] + p[8] + 0.5) * 24
				e.dir = Vector2.DOWN if int(p[2]) == 1 else Vector2.RIGHT
				e.pos += e.dir * 12
				e.open = int(p[3]) == 1 and int(p[6]) == 0
				if int(p[3]) == 0 and int(p[6]) == 0:
					e.trigger = e.pos
			11: e.trigger = Vector2(p[2], p[3])
		if type == 8:
			e.target = pos + e.dir * maxf(0, terrain.ray_distance(pos, e.dir) - 9.1)
		e.home = e.pos
		e.previous = e.pos
		entities.append(e)

func step(bits: int) -> void:
	events.clear()
	if won:
		return
	tick += 1
	for i in range(effects.size() - 1, -1, -1):
		effects[i].age += DT
		if effects[i].age > 0.45: effects.remove_at(i)
	if not ninja.alive:
		finish_death()
		step_after_death()
		return
	elapsed += DT
	time_left -= DT
	if time_left <= 0:
		time_left = 0
		ninja.kill("时间耗尽")
		finish_death()
		return
	ninja.begin_step(DT, bits, acceleration)
	for e in entities:
		e.previous = e.pos
		e.flash = maxf(0, e.flash - DT)
		e.cooldown = maxf(0, e.cooldown - DT)
		if not e.active:
			continue
		match int(e.type):
			0:
				if overlaps(e.pos, 6):
					e.active = false
					gold += 1
					time_left += 2
					events.append("gold")
			1: update_bounce(e)
			2: update_pad(e)
			3: update_turret(e)
			4: update_floor_guard(e)
			6: update_drone(e)
			7: update_oneway(e)
			8: update_thwump(e)
			9: update_door(e)
			10: update_rocket(e)
			11:
				if not e.open and overlaps(e.trigger, 6):
					e.open = true
					events.append("switch")
			12:
				if overlaps(e.pos, 4):
					detonate_mine(e)
	update_bullets()
	if ninja.alive: ninja.finish_step(terrain)
	if ninja.just_jumped and not events.has("jump"): events.append("jump")
	for e in entities:
		if int(e.type) == 8 and box_contact(ninja.pos, e.pos, Vector2(8.8, 8.8)).get("depth", 0) > 1:
			ninja.kill("挤压")
		if int(e.type) == 11 and e.open and overlaps(e.pos, 12) and ninja.alive:
			won = true
			events.append("win")
	if not ninja.alive:
		finish_death()

func finish_death() -> void:
	if ragdoll.active: return
	ragdoll.activate(ninja, rng)
	for e in entities:
		if e.type == 6:
			e.chasing = false
			e.state = 0
	events.append("death")

func step_after_death() -> void:
	ragdoll.step(terrain, DT)
	for e in entities:
		e.previous = e.pos
		e.flash = maxf(0, e.flash - DT)
		if not e.active: continue
		match int(e.type):
			1: update_bounce(e)
			4: update_floor_guard(e)
			6: update_drone(e)
			8: update_thwump(e)
			10: update_rocket(e)
			12:
				if ragdoll.touches(e.pos, 5): detonate_mine(e)
	update_bullets()

func detonate_mine(e: Dictionary) -> void:
	e.active = false
	effects.append({"pos": e.pos, "age": 0.0})
	if ninja.alive: ninja.kill("地雷", true, e.pos, (ninja.pos - e.pos).normalized() * 65)
	elif ragdoll.active: ragdoll.explode(e.pos, rng)

func overlaps(point: Vector2, radius: float) -> bool:
	return ninja.alive and ninja.pos.distance_squared_to(point) < pow(radius + NinjaBody.RADIUS, 2)

func update_bounce(e: Dictionary) -> void:
	e.velocity += (e.home - e.pos) * 80.0 * DT
	e.velocity *= pow(0.9, DT * 40)
	e.pos += e.velocity * DT
	if not ninja.alive: return
	var hit := box_contact(ninja.pos, e.pos, Vector2(9.6, 9.6))
	if not hit.is_empty():
		e.pos -= hit.normal * hit.depth * 0.8
		# Depenetration is a positional correction, not an impulse divided by DT.
		# The old conversion injected energy when a player spawned inside a block.
		var closing: float = (ninja.velocity - e.velocity).dot(hit.normal)
		if closing < 0:
			var impulse: Vector2 = hit.normal * (-closing * 1.1)
			ninja.velocity += impulse * 0.2
			e.velocity -= impulse * 0.8
		ninja.apply_contact(hit.normal, hit.depth * 0.2, e.velocity)

func update_pad(e: Dictionary) -> void:
	if not ninja.alive: return
	var delta: Vector2 = ninja.pos - e.pos
	if e.cooldown <= 0 and delta.length() < 16 and delta.dot(e.dir) > -4:
		var force: Vector2 = e.dir * (12.0 * 3 / 7 * 40)
		if force.y < 0:
			force.y *= 1 + absf(e.dir.y)
		ninja.velocity = force
		ninja.jumped = false
		e.cooldown = 0.15
		events.append("jump")

func update_oneway(e: Dictionary) -> void:
	if not ninja.alive: return
	var relative: Vector2 = ninja.pos - e.pos
	var before: Vector2 = ninja.previous_pos - e.pos
	var tangent := Vector2(-e.dir.y, e.dir.x)
	var depth: float = 22.0 - relative.dot(e.dir)
	if depth > 0 and before.dot(e.dir) >= 21.5 and absf(relative.dot(tangent)) < 22 and ninja.velocity.dot(e.dir) <= 0:
		ninja.apply_contact(e.dir, depth)

func update_door(e: Dictionary) -> void:
	var p: Array = e.p
	var triggered := overlaps(e.trigger, 5)
	if int(p[6]) == 1:
		if triggered and not e.open:
			e.open = true
			events.append("switch")
	elif int(p[3]) == 1:
		if triggered and e.open:
			e.open = false
			events.append("switch")
	else:
		if overlaps(e.pos, 12):
			e.open = true
			e.timer = 0.125
		else:
			e.timer -= DT
			e.open = e.timer > 0
	if not e.open and ninja.alive:
		var half := Vector2(12, 0.5) if absf(e.dir.y) > 0 else Vector2(0.5, 12)
		var hit := box_contact(ninja.pos, e.pos, half)
		if not hit.is_empty():
			ninja.apply_contact(hit.normal, hit.depth)

func update_thwump(e: Dictionary) -> void:
	var delta: Vector2 = ninja.pos - e.pos
	var tangent := Vector2(-e.dir.y, e.dir.x)
	if ninja.alive and e.state == 0 and delta.dot(e.dir) > 0 and absf(delta.dot(tangent)) < 19 and visible(e.pos, ninja.pos):
		e.state = 1
	if e.state == 1:
		e.pos = e.pos.move_toward(e.target, 171.428571 * DT)
		if e.pos.distance_to(e.target) < 0.01:
			e.state = 2
	elif e.state == 2:
		e.pos = e.pos.move_toward(e.home, 68.571429 * DT)
		if e.pos.distance_to(e.home) < 0.01:
			e.state = 0
	if not ninja.alive: return
	var hit := box_contact(ninja.pos, e.pos, Vector2(9, 9))
	if not hit.is_empty():
		if hit.normal.dot(e.dir) > 0.7:
			ninja.kill("冲撞方块")
		else:
			ninja.apply_contact(hit.normal, hit.depth, (e.pos - e.previous) / DT)

func update_floor_guard(e: Dictionary) -> void:
	var delta: Vector2 = ninja.pos - e.pos
	if ninja.alive and absf(delta.y) < 18 and visible(e.pos, ninja.pos):
		e.state = 1
		e.dir = Vector2(signf(delta.x), 0)
	if e.state == 1:
		var next: Vector2 = e.pos + e.dir * FLOOR_GUARD_SPEED * DT
		if terrain.solid(next + e.dir * 6) or not terrain.solid(next + e.dir * 6 + Vector2(0, 8)):
			e.state = 0
		else:
			e.pos = next
	if overlaps(e.pos, 6):
		ninja.kill("地面守卫")

func drone_edge_open(at: Vector2, direction: Vector2) -> bool:
	var next := at + direction * 24
	var cell := Vector2i(next / 24)
	return terrain.tile_id(cell.x, cell.y) == 0 and visible(at, next)

func drone_chase(e: Dictionary) -> bool:
	if not ninja.alive or int(e.p[3]) != 1 or int(e.p[4]) != 0: return false
	var cells := Vector2i(ninja.pos / 24) - Vector2i(e.pos / 24)
	var desired := Vector2.ZERO
	var distance := 0
	if cells.x == 0:
		desired = Vector2(0, signf(ninja.pos.y - e.pos.y))
		distance = absi(cells.y)
	elif cells.y == 0:
		desired = Vector2(signf(ninja.pos.x - e.pos.x), 0)
		distance = absi(cells.x)
	else: return false
	# Original AxisSearch refuses to reverse, then commits to the far end of
	# the visible corridor. It does not home toward the player every cell.
	if desired == Vector2.ZERO or desired.dot(e.dir) < -0.5: return false
	var goal: Vector2 = e.pos
	var reached := 0
	while reached < 33 and drone_edge_open(goal, desired):
		goal += desired * 24
		reached += 1
	if reached < distance or reached == 0: return false
	e.dir = desired
	e.target = goal
	e.chasing = true
	if int(e.p[2]) < 2:
		e.surface_grab = posmod(DIRECTIONS.find(desired) + (-1 if int(e.p[2]) == 0 else 1), 4)
	return true

func drone_next_goal(e: Dictionary) -> void:
	var heading := DIRECTIONS.find(e.dir)
	var mode := int(e.p[2])
	var surface_grab := int(e.surface_grab)
	e.surface_grab = -1
	e.chasing = false
	if surface_grab < 0 and drone_chase(e): return
	if surface_grab >= 0: heading = surface_grab
	var turns: Array = [1, 0, 3, 2] if mode % 2 == 0 else [3, 0, 1, 2]
	if mode in [2, 3, 4, 5]:
		var clockwise: bool = mode == 2 or (mode == 4 and not e.turn) or (mode == 5 and int(e.ai_ticks) % 2 == 0)
		turns = [0, 1, 3, 2] if clockwise else [0, 3, 1, 2]
	for turn in turns:
		var direction: Vector2 = DIRECTIONS[posmod(heading + int(turn), 4)]
		if drone_edge_open(e.pos, direction):
			e.dir = direction
			e.target = e.pos + direction * 24
			if mode == 4 and turn != 0: e.turn = not e.turn
			if mode == 5 and turn != 0: e.ai_ticks = 1 if int(e.ai_ticks) % 2 == 0 else 0
			return

func update_drone(e: Dictionary) -> void:
	var weapon := int(e.p[4])
	var speed := [68.571429, 17.142857, 25.714286][clampi(weapon, 0, 2)] as float
	e.ai_ticks += 1
	if e.pos.distance_to(e.target) < 0.001:
		e.pos = e.target
		drone_next_goal(e)
	e.pos = e.pos.move_toward(e.target, speed * (2 if e.chasing else 1) * DT)
	if overlaps(e.pos, 9):
		ninja.kill("无人机", false, e.pos, (ninja.pos - e.pos).normalized() * 60)
	if weapon == 0 or not ninja.alive: return
	e.timer += DT
	if weapon == 1:
		if e.state == 0 and e.timer >= 2.0 and visible(e.pos, ninja.pos):
			e.state = 2
			e.timer = 0.0
			e.aim = ninja.pos
		elif e.state == 2:
			e.aim = ninja.pos
			if e.timer >= 0.75:
				e.state = 3
				e.timer = 0.0
				e.shot = (e.aim - e.pos).normalized()
		elif e.state == 3:
			e.flash = 0.05
			laser_hit(e.pos, e.shot)
			if e.timer >= 0.175:
				e.state = 0
				e.timer = -1.0
	elif weapon == 2:
		if e.state == 0 and e.timer >= 1.5 and visible(e.pos, ninja.pos):
			e.state = 2
			e.timer = 0
			e.count = 0
		elif e.state == 2 and e.timer >= 0.875:
			e.state = 3
			e.timer = 0.15
		elif e.state == 3 and e.timer >= 0.15:
			e.timer = 0
			e.count += 1
			var direction: Vector2 = (ninja.pos - e.pos).normalized().rotated(rng.randf_range(-0.15, 0.15))
			bullets.append({"pos": e.pos, "velocity": direction * 400, "age": 0.0})
			if e.count >= 8:
				e.state = 0

func update_turret(e: Dictionary) -> void:
	if not ninja.alive: return
	var distance: float = e.aim.distance_to(ninja.pos)
	var tracking := 0.05 if distance < 24 else (0.035 if distance < 42 else 0.03)
	if e.state == 0:
		e.aim = e.aim.lerp(ninja.pos, 1 - pow(1 - tracking, DT * 40))
		e.timer += DT
		if e.timer >= 1.5 and visible(e.pos, ninja.pos):
			e.state = 1
			e.timer = 0
	elif e.state == 1:
		e.timer += DT
		if e.timer >= 0.25:
			e.shot = (e.aim - e.pos).normalized()
			laser_hit(e.pos, e.shot)
			e.flash = 0.12
			e.state = 2
			e.timer = 0
	else:
		e.timer += DT
		if e.timer >= 0.25:
			e.state = 0
			e.timer = 0

func update_rocket(e: Dictionary) -> void:
	if e.state == 0:
		if ninja.alive and visible(e.home, ninja.pos):
			e.timer += DT
			if e.timer >= 0.25:
				e.state = 1
				e.pos = e.home
				e.dir = (ninja.pos - e.home).normalized()
				e.speed = 4.0
				e.thrust = 160.0
				e.timer = 0.0
		else:
			e.timer = 0
	else:
		var desired: Vector2 = (ninja.pos - e.pos).normalized() if ninja.alive else e.dir
		var angle: float = e.dir.angle_to(desired)
		e.dir = e.dir.rotated(clampf(angle, -4 * DT, 4 * DT))
		e.thrust *= pow(1.1, DT * 40)
		e.speed = minf(137.142857, e.speed + e.thrust * DT)
		var next: Vector2 = e.pos + e.dir * e.speed * DT
		if terrain.solid(next) or not visible(e.pos, next):
			e.state = 0
			e.pos = e.home
			e.timer = -0.15
		else:
			e.pos = next
			if overlaps(e.pos, 3) or (ragdoll.active and ragdoll.touches(e.pos, 5)):
				effects.append({"pos": e.pos, "age": 0.0})
				if ninja.alive: ninja.kill("追踪导弹", true, e.pos, e.dir * 90)
				else: ragdoll.explode(e.pos, rng)
				e.state = 0
				e.pos = e.home
				e.timer = -0.15

func laser_hit(origin: Vector2, direction: Vector2) -> void:
	if not ninja.alive: return
	var end := origin + direction * ray_distance(origin, direction)
	if Geometry2D.get_closest_point_to_segment(ninja.pos, origin, end).distance_to(ninja.pos) < 10:
		ninja.kill("激光", false, origin, direction * 65)

func update_bullets() -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		var before: Vector2 = b.pos
		b.pos += b.velocity * DT
		b.age += DT
		if terrain.solid(b.pos) or not visible(before, b.pos) or b.age > 5:
			bullets.remove_at(i)
		elif ninja.alive and Geometry2D.get_closest_point_to_segment(ninja.pos, before, b.pos).distance_to(ninja.pos) < 10:
			ninja.kill("机枪", false, b.pos, b.velocity.normalized() * 75)
			bullets.remove_at(i)

func visible(a: Vector2, b: Vector2) -> bool:
	var delta := b - a
	return delta.length() < 0.01 or ray_distance(a, delta.normalized(), delta.length()) >= delta.length() - 0.1

func ray_distance(origin: Vector2, direction: Vector2, maximum: float = 1200.0) -> float:
	var result := terrain.ray_distance(origin, direction, maximum)
	for e in entities:
		if e.type != 9 or e.open:
			continue
		var tangent := Vector2(-e.dir.y, e.dir.x) * 12
		var hit = Geometry2D.segment_intersects_segment(origin, origin + direction * result, e.pos - tangent, e.pos + tangent)
		if hit is Vector2:
			result = minf(result, origin.distance_to(hit))
	return result

static func box_contact(point: Vector2, center: Vector2, half: Vector2) -> Dictionary:
	var local := point - center
	var nearest := local.clamp(-half, half)
	var delta := local - nearest
	var distance := delta.length()
	if distance >= 10:
		return {}
	if distance > 0.0001:
		return {"normal": delta / distance, "depth": 10 - distance}
	var gap := half - local.abs()
	if gap.x < gap.y:
		return {"normal": Vector2(1 if local.x >= 0 else -1, 0), "depth": 10 + gap.x}
	return {"normal": Vector2(0, 1 if local.y >= 0 else -1), "depth": 10 + gap.y}
