class_name NinjaDeathFXView
extends Node2D
var sim: NinjaSimulation
var paused := false

func _process(_delta: float) -> void:
	if sim != null: queue_redraw()

func _draw() -> void:
	if sim == null: return
	var fx := sim.death_fx
	var fraction := 1.0 if paused else Engine.get_physics_interpolation_fraction()
	for stain in fx.stains:
		var color: Color = stain.color
		color.a = clampf(12 - stain.age, 0, 1)
		draw_set_transform(stain.pos, (stain.normal as Vector2).angle() + PI / 2, Vector2(1.6, 0.55))
		draw_circle(Vector2.ZERO, stain.radius, color, true, -1, true)
	draw_set_transform(Vector2.ZERO)
	for drop in fx.drops:
		var at: Vector2 = drop.previous.lerp(drop.pos, fraction)
		var color: Color = drop.color
		color.a = clampf((drop.life - drop.age) * 4, 0, 1)
		var trail: Vector2 = (drop.velocity as Vector2).limit_length(240) * 0.018
		draw_line(at - trail, at, color, drop.radius * 1.4, true)
		draw_circle(at, drop.radius, color, true, -1, true)
	var alpha := clampf((0.4 - fx.electric_age) * 5, 0, 1)
	for arc in fx.arcs:
		draw_polyline(arc, Color(0.35, 0.55, 1, alpha * 0.55), 2.6, true)
		draw_polyline(arc, Color(0.92, 0.97, 1, alpha), 0.9, true)
	if not fx.arcs.is_empty() and sim.ragdoll.active:
		for bone in sim.ragdoll.bones.values():
			var a: Vector2 = sim.ragdoll.points[bone[0]].pos
			var b: Vector2 = sim.ragdoll.points[bone[1]].pos
			draw_line(a, b, Color(0.8, 0.9, 1, alpha * 0.55), 1, true)
