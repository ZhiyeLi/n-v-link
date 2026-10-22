extends Node2D
const INK := Color("282830")
const RED := Color("c84242")
const GOLD := Color("eee64d")
const BLUE := Color("3762b0")
var sim: NinjaSimulation
var terrain_view: Node2D
var animation_time := 0.0
var death_time := 0.0
var last_alive := true
var paused := false
var rig: NinjaRig
var collisions: NinjaCollisionView
var show_collisions := false
var skins: NinjaSkins
var skin_revision := -1
var preview_only := false
var preview_slot := ""

func _ready() -> void:
	terrain_view = Node2D.new()
	terrain_view.set_script(preload("res://view/terrain_view.gd"))
	terrain_view.show_behind_parent = true
	add_child(terrain_view)
	rig = NinjaRig.new()
	add_child(rig)
	collisions = NinjaCollisionView.new()
	collisions.z_index = 50
	add_child(collisions)
	if preview_only:
		terrain_view.hide()
		rig.hide()
		collisions.hide()

func preview_entity(slot: String) -> void:
	preview_slot = slot
	var types := {"gold": 0, "bounce": 1, "pad": 2, "turret": 3, "guard": 4, "drone_patrol": 6,
		"drone_scout": 6, "drone_laser": 6, "drone_chain": 6, "thwump": 8, "rocket": 10, "rocket_base": 10, "mine": 12}
	if not types.has(slot): hide(); return
	show()
	var parameters := [0, 0, 0, 0, 0, 0]
	if slot == "pad": parameters = [0, 0, 0, -1]
	if slot == "drone_scout": parameters[3] = 1
	if slot == "drone_laser": parameters[4] = 1
	if slot == "drone_chain": parameters[4] = 2
	sim = NinjaSimulation.new()
	sim.load_level({"id": "preview", "episode": 0, "slot": 0, "tiles": "0".repeat(713), "entities": [{"type": types[slot], "params": parameters}]})
	var e: Dictionary = sim.entities[0]
	e.pos = Vector2.ZERO
	e.previous = Vector2.ZERO
	e.home = Vector2.ZERO
	e.aim = Vector2(20, 0)
	if slot == "rocket": e.state = 1
	queue_redraw()

func load_simulation(value: NinjaSimulation) -> void:
	sim = value
	collisions.sim = sim
	terrain_view.terrain = sim.terrain
	terrain_view.queue_redraw()
	last_alive = true
	death_time = 0
	rig.joints.clear()
	rig.animate(sim.ninja, 1.0)

func _process(delta: float) -> void:
	if sim == null: return
	if preview_only:
		animation_time += delta
		queue_redraw()
		return
	if skins != null and skin_revision != skins.revision:
		skins.apply_rig(rig)
		skin_revision = skins.revision
	collisions.visible = show_collisions
	collisions.paused = paused
	var fraction := 1.0 if paused or sim.won else Engine.get_physics_interpolation_fraction()
	rig.visible = true
	if sim.ninja.alive:
		rig.position = sim.ninja.previous_pos.lerp(sim.ninja.pos, fraction)
		if not paused: rig.animate(sim.ninja, delta, fraction)
	elif sim.ragdoll.active:
		rig.set_ragdoll(sim.ragdoll, fraction)
	if not paused: animation_time += delta
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var fraction := 1.0 if paused or sim.won else Engine.get_physics_interpolation_fraction()
	for e in sim.entities:
		if not e.active:
			continue
		var p: Vector2 = e.previous.lerp(e.pos, fraction)
		var slot := entity_slot(e)
		var custom := skins.texture(slot) if skins != null else null
		if custom != null:
			draw_skin(custom, p, NinjaSkins.ENTITY_SIZES[slot], e)
			# Preserve weapon telegraphs and special lethal faces over the skin.
			if e.type == 8:
				var side := Vector2(-e.dir.y, e.dir.x) * 7
				draw_line(p + e.dir * 8 - side, p + e.dir * 8 + side, RED, 1.5)
			if e.type == 6 and int(e.p[4]) == 1:
				if e.state == 2: draw_line(p, e.aim, Color(0.7, 0.2, 0.2, 0.3), 0.7)
				if e.flash > 0: draw_line(p, p + e.shot * sim.ray_distance(p, e.shot), RED, 2, true)
			if not int(e.type) in [3, 10]: continue
		match int(e.type):
			0:
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("878128"))
				draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), GOLD)
			1:
				draw_line(e.home - Vector2(7, 0), p, Color("818189"), 1)
				draw_rect(Rect2(p - Vector2(9.6, 9.6), Vector2(19.2, 19.2)), Color("92929c"))
				draw_rect(Rect2(p - Vector2(9.6, 9.6), Vector2(19.2, 19.2)), INK, false, 1)
			2:
				var side := Vector2(-e.dir.y, e.dir.x) * 7
				draw_line(p - side, p + side, INK, 2, true)
				draw_polyline(PackedVector2Array([p - side * 0.7 + e.dir * 3, p + e.dir * 8, p + side * 0.7 + e.dir * 3]), INK, 1.4, true)
			3:
				if custom == null:
					draw_circle(p, 6, INK, false, 1.5, true)
					draw_line(p, p + (e.aim - p).normalized() * 10, INK, 2, true)
				if e.state == 1:
					draw_arc(e.aim, 5, 0, TAU, 16, RED, 1, true)
					draw_line(e.aim - Vector2(8, 0), e.aim + Vector2(8, 0), Color(0.7, 0.2, 0.2, 0.5), 0.7)
					var aiming_end: Vector2 = p + (e.aim - p).normalized() * sim.ray_distance(p, (e.aim - p).normalized())
					draw_line(p, aiming_end, Color(0.7, 0.2, 0.2, 0.12), 0.7)
				if e.flash > 0:
					draw_line(p, p + e.shot * sim.ray_distance(p, e.shot), RED, 1.3, true)
			4:
				draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), INK)
				draw_line(p + Vector2(-3, -2), p + Vector2(3, -2), RED, 2)
			6:
				var weapon := int(e.p[4])
				NinjaDroneIcon.draw_icon(self, p, int(e.p[3]) == 1 and weapon == 0, e.chasing, e.dir, animation_time, weapon)
				if weapon == 1 and e.state == 2:
					draw_line(p, e.aim, Color(0.7, 0.2, 0.2, 0.2), 0.7)
				if weapon == 1 and e.flash > 0:
					draw_line(p, p + e.shot * sim.ray_distance(p, e.shot), RED, 2, true)
			7:
				var side := Vector2(-e.dir.y, e.dir.x) * 12
				var face: Vector2 = p + e.dir * 12
				draw_line(face - side, face + side, INK, 2)
				for i in range(-2, 3):
					var at: Vector2 = face + side * i / 3.0
					draw_line(at, at - e.dir * 4 + side / 5, Color("777780"), 1)
			8:
				draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color("81818b"))
				draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), INK, false, 1)
				var side := Vector2(-e.dir.y, e.dir.x) * 7
				draw_line(p + e.dir * 8 - side, p + e.dir * 8 + side, RED, 2)
				draw_line(p + e.dir * 2 - side / 3, p + e.dir * 2 + side / 3, INK, 2)
			9:
				var side := Vector2(-e.dir.y, e.dir.x) * 12
				if not e.open:
					draw_line(p - side, p + side, INK, 2)
				else:
					draw_circle(p - side, 1.3, INK)
					draw_circle(p + side, 1.3, INK)
				if int(e.p[6]) == 1 or int(e.p[3]) == 1:
					draw_rect(Rect2(e.trigger - Vector2(3, 3), Vector2(6, 6)), INK, false, 1)
					if e.open:
						draw_circle(e.trigger, 1, INK)
			10:
				var base_skin := skins.texture("rocket_base") if skins != null else null
				if base_skin != null and preview_slot != "rocket": draw_skin(base_skin, e.home, NinjaSkins.ENTITY_SIZES.rocket_base, e)
				elif preview_slot != "rocket":
					draw_rect(Rect2(e.home - Vector2(6, 6), Vector2(12, 12)), INK, false, 1.5)
					draw_circle(e.home, 2.5, RED)
				if e.state == 1:
					var side := Vector2(-e.dir.y, e.dir.x) * 2.5
					if custom == null: draw_colored_polygon(PackedVector2Array([p + e.dir * 5, p - e.dir * 3 + side, p - e.dir * 3 - side]), RED)
					draw_line(p - e.dir * 4, p - e.dir * (8 + sin(animation_time * 80) * 2), GOLD, 1.5)
			11:
				draw_circle(p, 12, Color("92929d"), false, 1, true)
				draw_rect(Rect2(p - Vector2(6, 10), Vector2(12, 20)), INK, false, 1.3)
				if e.open:
					draw_rect(Rect2(p - Vector2(4, 8), Vector2(8, 16)), Color("e8e8ee"))
				else:
					draw_line(p - Vector2(4, 8), p + Vector2(4, 8), INK, 1)
				draw_circle(e.trigger, 5, GOLD if e.open else Color("878791"))
				draw_arc(e.trigger, 5, 0, TAU, 16, INK, 1, true)
				draw_line(e.trigger - Vector2(2, 0), e.trigger + Vector2(2, 0), INK, 1)
			12:
				for i in range(8):
					var ray := Vector2.from_angle(i * TAU / 8)
					draw_line(p + ray * 3, p + ray * 5.5, RED, 1, true)
				draw_circle(p, 3.5, RED)
				draw_circle(p - Vector2(1, 1), 1, Color("f0938c"))
	for bullet in sim.bullets:
		draw_line(bullet.pos, bullet.pos - bullet.velocity.normalized() * 4, RED, 1.5)
	for effect in sim.effects:
		var age: float = effect.age
		var color := Color(0.85, 0.38, 0.13, maxf(0, 1 - age / 0.45))
		draw_arc(effect.pos, 5 + age * 75, 0, TAU, 24, color, 1.2, true)
		for i in range(8):
			var ray := Vector2.from_angle(i * TAU / 8)
			draw_line(effect.pos + ray * age * 95, effect.pos + ray * (age * 95 + 4), color, 1, true)

static func entity_slot(e: Dictionary) -> String:
	match int(e.type):
		0: return "gold"
		1: return "bounce"
		2: return "pad"
		3: return "turret"
		4: return "guard"
		6:
			if int(e.p[4]) == 1: return "drone_laser"
			if int(e.p[4]) == 2: return "drone_chain"
			return "drone_scout" if int(e.p[3]) == 1 else "drone_patrol"
		8: return "thwump"
		10: return "rocket" if e.state == 1 else ""
		12: return "mine"
	return ""

func draw_skin(texture: Texture2D, at: Vector2, maximum: Vector2, entity: Dictionary) -> void:
	var ratio := minf(maximum.x / texture.get_width(), maximum.y / texture.get_height())
	var dimensions := texture.get_size() * ratio
	var rotation := 0.0
	var mirror := Vector2.ONE
	if entity.type == 10 and entity.state == 1 and at != entity.home: rotation = entity.dir.angle()
	elif entity.type in [4, 6] and entity.dir.x < 0: mirror.x = -1
	draw_set_transform(at, rotation, mirror)
	draw_texture_rect(texture, Rect2(-dimensions * 0.5, dimensions), false)
	draw_set_transform(Vector2.ZERO)
