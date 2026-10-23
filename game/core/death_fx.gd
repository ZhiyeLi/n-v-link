class_name NinjaDeathFX
extends RefCounted
## N 1.4 reference: six SpawnZap strokes; Explode spurts at detached limb roots.
## Cosmetic particles have their own RNG and never modify the gameplay body.
const MAX_DROPS := 160
const MAX_STAINS := 220
var drops: Array[Dictionary] = []
var stains: Array[Dictionary] = []
var arcs: Array[PackedVector2Array] = []
var electric_age := 1.0
var electric_origin := Vector2.ZERO
var clock := 0
var rng := RandomNumberGenerator.new()

func start(n: NinjaBody, rag: NinjaRagdoll, seed_value: int) -> void:
	rng.seed = seed_value
	match n.death_kind:
		NinjaBody.DeathKind.ELECTRIC:
			electric_age = 0
			electric_origin = n.death_origin
			refresh_arcs(rag)
		NinjaBody.DeathKind.EXPLOSIVE: explode(rag, n.death_origin)
		NinjaBody.DeathKind.FALL:
			spurt(n.pos + Vector2(0, 7), 12, 25, 85, Vector2(n.incoming_velocity.x * 0.12, -25))
		NinjaBody.DeathKind.SHOT: spurt(n.pos, 18, 30, 100, n.death_impulse * 0.3)

func explode(rag: NinjaRagdoll, origin: Vector2) -> void:
	spurt(origin, 28, 65, 210, Vector2(0, -35))
	for limb in ["left_upper_arm", "right_upper_arm", "left_thigh", "right_thigh"]:
		var at: Vector2 = rag.points[rag.bones[limb][0]].pos
		spurt(at, 16, 55, 180, (at - origin).normalized() * 30 + Vector2(0, -25))

func spurt(at: Vector2, count: int, minimum: float, maximum: float, bias: Vector2) -> void:
	for i in range(mini(count, MAX_DROPS - drops.size())):
		var pos := at + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		drops.append({"pos": pos, "previous": pos,
			"velocity": Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(minimum, maximum) + bias,
			"age": 0.0, "life": rng.randf_range(1.1, 2.2), "radius": rng.randf_range(0.45, 1.35),
			"color": Color(rng.randf_range(0.56, 0.82), 0.025, 0.055)})

func refresh_arcs(rag: NinjaRagdoll) -> void:
	arcs.clear()
	var targets := ["head", "shoulder", "hip", "left_hand", "right_hand", "left_ankle"]
	for target in targets:
		var end: Vector2 = rag.points[target].pos
		var start := electric_origin + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		var side := (end - start).orthogonal().normalized()
		if side == Vector2.ZERO: side = Vector2.RIGHT
		var path := PackedVector2Array([start])
		for i in range(1, 6):
			path.append(start.lerp(end, i / 6.0) + side * rng.randf_range(-5, 5))
		path.append(end)
		arcs.append(path)

func step(terrain: NinjaTerrain, rag: NinjaRagdoll, dt: float) -> void:
	clock += 1
	electric_age += dt
	if electric_age < 0.4 and rag.active:
		if clock % 4 == 0: refresh_arcs(rag)
	else: arcs.clear()
	for i in range(drops.size() - 1, -1, -1):
		var p := drops[i]
		p.previous = p.pos
		p.age += dt
		p.velocity *= pow(0.98, dt * 40)
		p.velocity.y += 240 * dt
		p.pos += p.velocity * dt
		var hit := terrain.contact(p.pos, p.radius)
		if not hit.is_empty():
			var at: Vector2 = p.pos + hit.normal * (hit.depth + 0.01)
			if stains.size() >= MAX_STAINS: stains.pop_front()
			stains.append({"pos": at, "normal": hit.normal, "radius": p.radius * rng.randf_range(1.1, 2.4), "age": 0.0, "color": p.color})
			drops.remove_at(i)
		elif p.age >= p.life: drops.remove_at(i)
	for i in range(stains.size() - 1, -1, -1):
		stains[i].age += dt
		if stains[i].age >= 12: stains.remove_at(i)
