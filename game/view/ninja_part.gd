class_name NinjaPart
extends Node2D
## Each bone owns its visual. A skin can replace one part without touching motion.
var length := 5.0
var thickness := 1.55
var head := false
var color := Color("282830")
var texture: Texture2D
var texture_region := Rect2()
var image_layout: Dictionary = {}
var image_scale := 1.0

func _draw() -> void:
	if texture != null:
		var config := image_layout if not image_layout.is_empty() else NinjaRigLayout.defaults(name, texture_region)
		var size := NinjaRigLayout.image_size(config, texture_region, image_scale)
		var pivot := NinjaRigLayout.anchor(config, "pivot")
		var axis := (NinjaRigLayout.anchor(config, "tip") - pivot) * size
		draw_set_transform(Vector2.ZERO, -axis.angle())
		draw_texture_rect_region(texture, Rect2(-pivot * size, size), texture_region)
		draw_set_transform(Vector2.ZERO)
	elif head:
		draw_circle(Vector2.ZERO, 2.6, color, true, -1, true)
		# Small profile cue makes the last-input facing direction visible.
		draw_line(Vector2(1.9, -0.3), Vector2(3.1, 0.6), color, 1, true)
	else:
		draw_line(Vector2.ZERO, Vector2(length, 0), color, thickness, true)
		draw_circle(Vector2.ZERO, thickness * 0.46, color, true, -1, true)
