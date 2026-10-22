class_name NinjaSkinPreview
extends Node2D
var skins: NinjaSkins
var slot := "drone_patrol"
var rig: NinjaRig
var age := 0.0
var mode := 0
var facing := 1.0
var draw_hitbox := true
var last_revision := -1
var last_slot := ""
var entity_view: Node2D
var hitbox_layer := Node2D.new()
const STANCES := ["run", "rise", "fall", "wall_climb", "wall_slide", "wall_jump"]

func _ready() -> void:
	rig = NinjaRig.new()
	add_child(rig)
	entity_view = Node2D.new()
	entity_view.set_script(preload("res://view/world_view.gd"))
	entity_view.preview_only = true
	entity_view.skins = skins
	entity_view.position = Vector2(340, 140)
	entity_view.scale = Vector2(5, 5)
	add_child(entity_view)
	hitbox_layer.z_index = 50
	add_child(hitbox_layer)
	hitbox_layer.draw.connect(draw_hitboxes)

func _process(dt: float) -> void:
	age += dt
	if skins == null: return
	if last_slot != slot:
		entity_view.preview_entity(slot)
		last_slot = slot
	if last_revision != skins.revision:
		skins.apply_rig(rig)
		last_revision = skins.revision
	var vertical := -60.0 if mode in [1, 3, 5] else 70.0
	rig.set_pose(NinjaAnimation.make_pose(STANCES[mode], age * 8, 216, vertical, 1), 1, STANCES[mode])
	var bounds := rig.visual_bounds()
	var factor := minf(5, minf(165 / maxf(1, bounds.size.x), 205 / maxf(1, bounds.size.y)))
	rig.scale = Vector2(facing * factor, factor)
	rig.position = Vector2(105 - bounds.get_center().x * facing * factor, 215 - bounds.end.y * factor)
	queue_redraw()
	hitbox_layer.queue_redraw()

func _draw() -> void:
	# Checkerboard makes transparent padding visible without changing artwork.
	for y in range(13):
		for x in range(24):
			draw_rect(Rect2(x * 20, y * 20, 20, 20), Color("dcdce5") if (x + y) % 2 == 0 else Color("d4d4df"))
	draw_line(Vector2(30, 215), Vector2(180, 215), Color("9494a2"), 1)
	if mode in [3, 4, 5]: draw_line(Vector2(155, 70), Vector2(155, 212), Color("9494a2"), 2)
	if skins == null: return
	var texture := skins.texture(slot)
	if texture != null and slot.begins_with("player_"):
		var size := texture.get_size()
		var bounds: Vector2 = NinjaSkins.ENTITY_SIZES.get(slot, Vector2(31, 31)) * 5
		var ratio := minf(bounds.x / size.x, bounds.y / size.y)
		draw_texture_rect(texture, Rect2(Vector2(340, 140) - size * ratio * 0.5, size * ratio), false)
	elif slot.begins_with("player_"):
		# Default player part, using the same vector renderer as gameplay.
		var sample := rig.parts[slot.trim_prefix("player_")] as NinjaPart
		if sample.head: draw_circle(Vector2(340, 140), 13, sample.color)
		else: draw_line(Vector2(315, 140), Vector2(365, 140), sample.color, sample.thickness * 5, true)

func draw_hitboxes() -> void:
	if not draw_hitbox: return
	hitbox_layer.draw_arc(rig.position, NinjaBody.RADIUS * absf(rig.scale.x), 0, TAU, 48, Color(0.1, 0.6, 0.7, 0.7), 1, true)
	if slot.begins_with("drone_"): hitbox_layer.draw_arc(Vector2(340, 140), 45, 0, TAU, 48, Color(0.8, 0.2, 0.25, 0.7), 1, true)
	elif slot == "guard": hitbox_layer.draw_arc(Vector2(340, 140), 30, 0, TAU, 48, Color(0.8, 0.2, 0.25, 0.7), 1, true)
	elif slot in ["thwump", "bounce"]:
		var half := 45.0 if slot == "thwump" else 48.0
		hitbox_layer.draw_rect(Rect2(Vector2(340, 140) - Vector2.ONE * half, Vector2.ONE * half * 2), Color(0.1, 0.6, 0.7, 0.7), false, 1)
