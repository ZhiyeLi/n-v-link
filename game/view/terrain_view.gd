extends Node2D
var terrain: NinjaTerrain
var background: Texture2D
func _draw() -> void:
	if terrain == null:
		return
	draw_rect(Rect2(0, 0, 792, 600), Color("c9c9d0"))
	if background != null:
		var factor := maxf(792.0/background.get_width(),600.0/background.get_height())
		var region_size := Vector2(792,600)/factor
		draw_texture_rect_region(background,Rect2(0,0,792,600),Rect2((background.get_size()-region_size)/2,region_size))
	for polygon in terrain.polygons:
		draw_colored_polygon(polygon, Color("56565e"))
	for edge in terrain.segments:
		draw_line(edge.a, edge.b, Color("44444c"), 0.8, true)
