extends Node2D
var terrain: NinjaTerrain
func _draw() -> void:
	if terrain == null:
		return
	draw_rect(Rect2(0, 0, 792, 600), Color("c9c9d0"))
	for polygon in terrain.polygons:
		draw_colored_polygon(polygon, Color("56565e"))
	for edge in terrain.segments:
		draw_line(edge.a, edge.b, Color("44444c"), 0.8, true)
