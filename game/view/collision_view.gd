class_name NinjaCollisionView
extends Node2D
## Draw the actual collision primitives, not the normalized texture bounds.
var sim: NinjaSimulation
var paused := false
const SOLID := Color(0.15, 0.85, 0.95, 0.8)
const DANGER := Color(1.0, 0.2, 0.3, 0.95)
const TRIGGER := Color(1.0, 0.8, 0.15, 0.9)

func _process(_dt: float) -> void:
	if visible: queue_redraw()

func circle(at: Vector2, radius: float, color: Color) -> void:
	draw_arc(at, radius, 0, TAU, 40, color, 0.8, true)
	draw_line(at - Vector2(2, 0), at + Vector2(2, 0), color, 0.6)
	draw_line(at - Vector2(0, 2), at + Vector2(0, 2), color, 0.6)

func _draw() -> void:
	if sim == null: return
	var fraction := 1.0 if paused or sim.won else Engine.get_physics_interpolation_fraction()
	for edge in sim.terrain.segments: draw_line(edge.a, edge.b, Color(0.15, 0.85, 0.95, 0.42), 0.6)
	if sim.ninja.alive:
		circle(sim.ninja.previous_pos.lerp(sim.ninja.pos, fraction), NinjaBody.RADIUS, SOLID)
	elif sim.ragdoll.active:
		for key in sim.ragdoll.points:
			var point: Dictionary = sim.ragdoll.points[key]
			circle(point.previous.lerp(point.pos, fraction), 2.6 if key == "head" else 0.8, SOLID)
	for e in sim.entities:
		if not e.active: continue
		var p: Vector2 = e.previous.lerp(e.pos, fraction)
		match int(e.type):
			0: circle(p, 6, TRIGGER)
			1: draw_rect(Rect2(p - Vector2(9.6, 9.6), Vector2(19.2, 19.2)), SOLID, false, 0.8)
			2:
				# This trigger tests the player's center and a directional half-plane.
				var angle: float = e.dir.angle()
				var arc := acos(-4.0 / 16.0)
				var side := Vector2(-e.dir.y, e.dir.x) * sqrt(240.0)
				draw_arc(p, 16, angle - arc, angle + arc, 40, TRIGGER, 0.8, true)
				draw_line(p - e.dir * 4 - side, p - e.dir * 4 + side, TRIGGER, 0.8)
				draw_line(p, p + e.dir * 16, TRIGGER, 1)
			3:
				if e.flash > 0: draw_line(p, p + e.shot * sim.ray_distance(p, e.shot), DANGER, 0.8)
			4: circle(p, 6, DANGER)
			6:
				circle(p, 9, DANGER)
				if int(e.p[4]) == 1 and e.state == 3: draw_line(e.pos, sim.laser_beam_end(e), DANGER, 0.8)
			7:
				var tangent := Vector2(-e.dir.y, e.dir.x) * 12
				draw_line(p + e.dir * 12 - tangent, p + e.dir * 12 + tangent, SOLID, 1.2)
				draw_line(p + e.dir * 12, p + e.dir * 17, SOLID, 1)
			8: draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), DANGER, false, 0.8)
			9:
				if not e.open:
					var half := Vector2(12, 0.5) if absf(e.dir.y) > 0 else Vector2(0.5, 12)
					draw_rect(Rect2(p - half, half * 2), SOLID, false, 1)
				if int(e.p[6]) == 1 or int(e.p[3]) == 1: circle(e.trigger, 5, TRIGGER)
				else: circle(p, 12, TRIGGER)
			11:
				circle(p, 12, TRIGGER)
				circle(e.trigger, 6, TRIGGER)
			10:
				if e.state == 1: circle(p, 3, DANGER)
			12: circle(p, 4, DANGER)
	for bullet in sim.bullets:
		draw_line(bullet.pos - bullet.velocity * NinjaSimulation.DT, bullet.pos, DANGER, 1.0)
