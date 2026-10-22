class_name NinjaAnchorCanvas
extends Control
signal edited
var skins: NinjaSkins
var part := "head"
var image_rect := Rect2()
var dragging := ""
var last_revision := -1
var region := Rect2()

func _process(_dt: float) -> void:
	if last_revision != skins.revision:
		region = Rect2(skins.texture("player_" + part).get_image().get_used_rect())
		last_revision = skins.revision
		queue_redraw()

func _draw() -> void:
	for y in range(17):
		for x in range(20): draw_rect(Rect2(x * 20, y * 20, 20, 20), Color("d2d2dc") if (x + y) % 2 == 0 else Color("e1e1e8"))
	if region.size.x <= 0: return
	var factor := minf(290 / region.size.x, 250 / region.size.y)
	var dimensions := region.size * factor
	image_rect = Rect2(size * 0.5 - dimensions * 0.5, dimensions)
	draw_texture_rect_region(skins.texture("player_" + part), image_rect, region)
	var config: Dictionary = skins.layout.parts[part]
	var a := image_rect.position + NinjaRigLayout.anchor(config, "pivot") * image_rect.size
	var b := image_rect.position + NinjaRigLayout.anchor(config, "tip") * image_rect.size
	draw_line(a, b, Color("607780"), 2, true)
	for item in [[a, Color("219bc0")], [b, Color("e48b28")]]:
		draw_circle(item[0], 8, Color.WHITE, true, -1, true)
		draw_circle(item[0], 6, item[1], true, -1, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: dragging = ""; return
		var config: Dictionary = skins.layout.parts[part]
		var a := image_rect.position + NinjaRigLayout.anchor(config, "pivot") * image_rect.size
		var b := image_rect.position + NinjaRigLayout.anchor(config, "tip") * image_rect.size
		dragging = "pivot" if event.position.distance_to(a) <= event.position.distance_to(b) else "tip"
		move_anchor(event.position)
		accept_event()
	elif event is InputEventMouseMotion and not dragging.is_empty():
		move_anchor(event.position)
		accept_event()

func move_anchor(at: Vector2) -> void:
	if image_rect.size.x <= 0 or dragging.is_empty(): return
	var uv := (at - image_rect.position) / image_rect.size
	skins.set_layout_value(part, dragging + "_x", uv.x)
	skins.set_layout_value(part, dragging + "_y", uv.y)
	edited.emit()
