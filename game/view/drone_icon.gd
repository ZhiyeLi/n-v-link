class_name NinjaDroneIcon
extends RefCounted
## Original N 1.4 zapdrone_move/chaseidle geometry: octagon, cyan fill,
## directional eye; the scout adds its distinctive antenna.
static var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/n14_drone_shapes.json"))

static func draw_icon(canvas: Node2D, at: Vector2, scout: bool, chasing: bool, direction: Vector2, time: float, weapon: int = 0) -> void:
	var shape: Dictionary = shapes["802" if scout else "801"]
	var fill := Color("79cbe3") if weapon == 0 else Color("cd7878")
	if chasing: fill = fill.lerp(Color("f1ed9a"), 0.3 + 0.25 * sin(time * 15))
	# Both shapes consist of straight edges. Positive-side fill contours form
	# the outer body, inset and antenna cap; draw them in their SWF style order.
	for fill_index in range(1, shape.fills.size() + 1):
		var polygon := PackedVector2Array()
		for edge in shape.edges:
			if int(edge[4]) == fill_index:
				polygon.append(at + Vector2(edge[0][0], edge[0][1]) * 0.18)
		if polygon.size() >= 3:
			canvas.draw_colored_polygon(polygon, fill if fill_index == shape.fills.size() else Color("282830"))
	for edge in shape.edges:
		if int(edge[5]) > 0:
			canvas.draw_line(at + Vector2(edge[0][0], edge[0][1]) * 0.18, at + Vector2(edge[2][0], edge[2][1]) * 0.18, Color("282830"), 0.7, true)
	var eye := at + direction * 3.7
	canvas.draw_circle(eye, 2.2, Color("282830"), true, -1, true)
	canvas.draw_circle(eye + direction * 0.5, 0.7, Color("eeeeef"), true, -1, true)
