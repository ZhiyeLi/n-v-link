class_name NinjaRigEditor
extends Window
var host: Node
var skins: NinjaSkins
var part := "head"
var rig: NinjaRig
var canvas: NinjaAnchorCanvas
var fields: Dictionary = {}
var controls := Control.new()
var age := 0.0
var pose_index := 0
var facing := 1.0
var last_revision := -1
var originals: Dictionary

func _ready() -> void:
	size = Vector2i(900, 680)
	min_size = size
	title = "关节与比例 · " + NinjaSkins.PART_LABELS[part]
	transient = true
	exclusive = true
	wrap_controls = true
	theme = host.ui.theme
	skins.ensure_layout("player_" + part)
	originals = skins.layout.duplicate(true)
	add_child(controls)
	var paper := ColorRect.new()
	paper.color = host.PAPER
	paper.size = Vector2(900, 680)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(paper)
	host.label(controls, "关节与比例 · " + NinjaSkins.PART_LABELS[part], Vector2(28, 18), Vector2(560, 38), 24)
	host.label(controls, "拖动蓝点（近端）与橙点（远端）调整关节。图像始终等比缩放。", Vector2(28, 59), Vector2(850, 28), 14, host.MUTED)
	canvas = NinjaAnchorCanvas.new()
	canvas.position = Vector2(28, 99)
	canvas.size = Vector2(400, 340)
	canvas.clip_contents = true
	canvas.skins = skins
	canvas.part = part
	controls.add_child(canvas)
	canvas.edited.connect(sync_fields)
	rig = NinjaRig.new()
	controls.add_child(rig)
	rig.position = Vector2(660, 325)
	rig.scale = Vector2(5, 5)
	host.label(controls, "整体等比尺寸", Vector2(500, 100), Vector2(150, 28), 14)
	var overall := SpinBox.new()
	overall.position = Vector2(660, 96)
	overall.size = Vector2(120, 34)
	overall.min_value = 0.25
	overall.max_value = 3
	overall.step = 0.05
	overall.value = skins.layout.get("scale", 1.0)
	overall.value_changed.connect(func(value: float): skins.layout.scale = value; skins.save())
	controls.add_child(overall)
	fields["global_scale"] = overall
	var animation := OptionButton.new()
	animation.position = Vector2(500, 390)
	animation.size = Vector2(160, 35)
	for value in ["跑动", "上升", "下落", "贴墙上升", "滑墙", "蹬墙", "参考站姿"]: animation.add_item(value)
	animation.item_selected.connect(func(index: int): pose_index = index)
	controls.add_child(animation)
	host.button(controls, "转身", Rect2(680, 390, 100, 35), func(): facing *= -1)
	host.label(controls, "预览自动适配区域；游戏中使用设定的实际尺寸。", Vector2(495, 429), Vector2(380, 24), 12, host.MUTED)
	var names := {"width": "图像宽度", "pivot_x": "近端 X", "pivot_y": "近端 Y", "tip_x": "远端 X", "tip_y": "远端 Y",
		"offset_x": "连接偏移 X", "offset_y": "连接偏移 Y", "angle": "角度偏移"}
	var index := 0
	for key in names:
		var at := Vector2(28 + index % 4 * 217, 460 + int(index / 4) * 65)
		host.label(controls, names[key], at, Vector2(100, 25), 13)
		var spin := SpinBox.new()
		spin.position = at + Vector2(100, -3)
		spin.size = Vector2(100, 32)
		spin.min_value = NinjaRigLayout.LIMITS[key][0]
		spin.max_value = NinjaRigLayout.LIMITS[key][1]
		spin.step = 0.01 if key in ["pivot_x", "pivot_y", "tip_x", "tip_y"] else 0.1
		spin.value = skins.layout.parts[part].get(key, 0)
		spin.value_changed.connect(func(value: float): skins.set_layout_value(part, key, value))
		controls.add_child(spin)
		fields[key] = spin
		index += 1
	host.label(controls, "锚点坐标以裁剪后图像为基准：左上为 0，右下为 1。只改变外观，碰撞箱保持原样。", Vector2(28, 579), Vector2(844, 25), 13, host.MUTED)
	host.button(controls, "撤销本次调整", Rect2(28, 623, 175, 36), func(): skins.layout = originals.duplicate(true); skins.save(); sync_fields())
	host.button(controls, "完成", Rect2(725, 623, 147, 36), queue_free, true)
	close_requested.connect(queue_free)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen())
			set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_pause"):
			queue_free()
			set_input_as_handled())

func sync_fields() -> void:
	for key in fields: fields[key].set_value_no_signal(skins.layout.get("scale", 1.0) if key == "global_scale" else skins.layout.parts[part].get(key, 0))

func _process(dt: float) -> void:
	if rig == null: return
	age += dt
	if last_revision != skins.revision:
		skins.apply_rig(rig)
		last_revision = skins.revision
	var stance: String = "idle" if pose_index == 6 else NinjaSkinPreview.STANCES[pose_index]
	rig.set_pose(NinjaAnimation.make_pose(stance, age * 8, 216, -60 if pose_index in [1, 3, 5] else 70, 1), 1, stance)
	var bounds := rig.visual_bounds()
	var preview_scale := minf(5, minf(290 / maxf(1, bounds.size.x), 220 / maxf(1, bounds.size.y)))
	rig.scale = Vector2(preview_scale * facing, preview_scale)
	rig.position = Vector2(660 - bounds.get_center().x * facing * preview_scale, 370 - bounds.end.y * preview_scale)
