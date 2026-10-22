class_name NinjaRagdoll
extends RefCounted
## Fixed-step Verlet particles; ordinary deaths share shoulder/hip joints.
## Explosions duplicate the four limb roots, as N 1.4 Ragdoll.Explode does.
var active := false
var exploded := false
var points: Dictionary = {}
var sticks: Array[Dictionary] = []
var bones: Dictionary = {}
var age := 0.0

func activate(n: NinjaBody, rng: RandomNumberGenerator) -> void:
	active = true
	var pose := n.visual_pose()
	for key in pose:
		if key == "nose": continue
		var local: Vector2 = pose[key] * Vector2(n.facing, 1)
		var p := n.pos + local
		var velocity := n.incoming_velocity * 0.75 + n.death_impulse
		if not n.previous_pose.is_empty():
			velocity += ((pose[key] - n.previous_pose[key]) * Vector2(n.facing, 1) / NinjaSimulation.DT).limit_length(90)
		points[key] = {"pos": p, "old": p - velocity * NinjaSimulation.DT, "previous": p}
	for part in NinjaRig.PARTS:
		var ends: Array = NinjaRig.ENDS[part].duplicate()
		if part == "head": ends = ["head", "shoulder"]
		bones[part] = ends
		add_stick(ends[0], ends[1])
	# Keep the head on the torso while elbows and knees can fold naturally.
	add_stick("hip", "head")
	if n.death_explosive: explode(n.death_origin, rng)

func add_stick(a: String, b: String) -> void:
	sticks.append({"a": a, "b": b, "length": points[a].pos.distance_to(points[b].pos)})

func explode(origin: Vector2, rng: RandomNumberGenerator) -> void:
	if exploded: return
	exploded = true
	for limb in ["left_upper_arm", "right_upper_arm", "left_thigh", "right_thigh"]:
		var old_root: String = bones[limb][0]
		var new_root: String = limb + "_root"
		points[new_root] = points[old_root].duplicate(true)
		bones[limb][0] = new_root
		for stick in sticks:
			if stick.a == old_root and stick.b == bones[limb][1]: stick.a = new_root
		var kick := Vector2(rng.randf_range(-135, 135), rng.randf_range(-230, -115))
		points[new_root].old -= kick * NinjaSimulation.DT
	for key in points:
		var away: Vector2 = (points[key].pos - origin).normalized()
		points[key].old -= away * 55 * NinjaSimulation.DT

func step(terrain: NinjaTerrain, dt: float) -> void:
	if not active: return
	age += dt
	for key in points:
		var p: Dictionary = points[key]
		p.previous = p.pos
		var velocity: Vector2 = (p.pos - p.old) * pow(0.99, dt * 40)
		p.old = p.pos
		p.pos += velocity + Vector2(0, 240 * dt * dt)
	for iteration in range(10):
		for stick in sticks:
			var a: Dictionary = points[stick.a]
			var b: Dictionary = points[stick.b]
			var delta: Vector2 = b.pos - a.pos
			var length := delta.length()
			if length > 0.00001:
				var correction: Vector2 = delta * ((length - stick.length) / length * 0.5)
				a.pos += correction
				b.pos -= correction
		for key in points:
			var p: Dictionary = points[key]
			var hit := terrain.contact(p.pos, 2.6 if key == "head" else 0.8)
			if not hit.is_empty():
				var velocity: Vector2 = p.pos - p.old
				p.pos += hit.normal * (hit.depth + 0.0001)
				if velocity.dot(hit.normal) < 0:
					velocity = velocity.bounce(hit.normal) * 0.35
				p.old = p.pos - velocity * 0.85

func touches(center: Vector2, radius: float) -> bool:
	for p in points.values():
		if (p.pos as Vector2).distance_squared_to(center) < radius * radius: return true
	return false
