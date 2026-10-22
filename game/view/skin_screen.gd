extends Control
var host: Node
var skins: NinjaSkins
var panel: Panel
var rows: VBoxContainer
var preview: NinjaSkinPreview
var slot := "drone_patrol"
var category := "entities"
var heading: Label
var detail: Label
var notice: Label
var dialog: FileDialog
var selected_file_slot := ""
var layout_button: Button
var rig_editor: NinjaRigEditor

func _ready() -> void:
	size = Vector2(1024, 768)
	panel = Panel.new()
	panel.position = Vector2(56, 32)
	panel.size = Vector2(912, 704)
	panel.add_theme_stylebox_override("panel", host.box(host.PAPER, 10))
	add_child(panel)
	host.label(panel, "自定义贴图", Vector2(30, 22), Vector2(520, 42), 28)
	host.button(panel, "返回首页", Rect2(755, 25, 127, 37), host.show_menu)
	host.button(panel, "场景实体", Rect2(30, 82, 125, 36), func(): select_category("entities"))
	host.button(panel, "角色部位", Rect2(166, 82, 125, 36), func(): select_category("player"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 135)
	scroll.size = Vector2(262, 420)
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	heading = host.label(panel, "", Vector2(328, 82), Vector2(548, 32), 21)
	layout_button = host.button(panel, "关节与比例…", Rect2(700, 82, 155, 35), edit_layout)
	detail = host.label(panel, "", Vector2(328, 120), Vector2(548, 28), 13, host.MUTED)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview = NinjaSkinPreview.new()
	preview.skins = skins
	var frame := Control.new()
	frame.position = Vector2(328, 157)
	frame.size = Vector2(480, 260)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	frame.add_child(preview)
	host.label(panel, "角色动作预览", Vector2(350, 421), Vector2(180, 25), 13, host.MUTED)
	host.label(panel, "当前对象贴图", Vector2(620, 421), Vector2(180, 25), 13, host.MUTED)
	var animation := OptionButton.new()
	animation.position = Vector2(328, 458)
	animation.size = Vector2(157, 34)
	for text in ["跑动", "上升", "下落", "贴墙上升", "滑墙", "蹬墙"]: animation.add_item(text)
	animation.item_selected.connect(func(index: int): preview.mode = index)
	panel.add_child(animation)
	host.button(panel, "转身", Rect2(496, 458, 76, 34), func(): preview.facing *= -1)
	var hitbox := CheckButton.new()
	hitbox.text = "预览碰撞箱"
	hitbox.position = Vector2(602, 458)
	hitbox.button_pressed = true
	hitbox.toggled.connect(func(on: bool): preview.draw_hitbox = on)
	panel.add_child(hitbox)
	host.button(panel, "导入图片…", Rect2(328, 510, 220, 42), open_import, true)
	host.button(panel, "恢复当前对象", Rect2(562, 510, 220, 42), func(): skins.remove(slot); refresh("已恢复默认贴图。"))
	notice = host.label(panel, "", Vector2(30, 569), Vector2(852, 42), 13, host.MUTED)
	host.button(panel, "应用两个测试用例", Rect2(30, 625, 210, 40), func():
		var result := skins.install_demo()
		refresh(result.message))
	host.button(panel, "恢复全部默认", Rect2(252, 625, 157, 40), func(): skins.reset_all(); refresh("已恢复全部默认贴图。"))
	host.label(panel, "测试资源：能天使 / 源石虫 · PRTS\n原图版权归鹰角网络及关联权利人。", Vector2(454, 623), Vector2(425, 42), 12, host.MUTED)
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = false
	dialog.title = "选择贴图图片"
	# The file picker uses Godot's dark panels; avoid inheriting the page's
	# dark-on-paper text colors, which make its labels unreadable.
	var picker_theme := Theme.new()
	picker_theme.default_font = host.font
	for type_name in ["Label", "Button", "CheckButton", "CheckBox"]:
		picker_theme.set_color("font_color", type_name, Color("eeeeef"))
		picker_theme.set_color("font_hover_color", type_name, Color.WHITE)
		picker_theme.set_color("font_focus_color", type_name, Color.WHITE)
	dialog.theme = picker_theme
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片（PNG / JPG / WebP）"])
	dialog.current_dir = skins.directory
	add_child(dialog)
	dialog.get_ok_button().text = "导入"
	dialog.get_cancel_button().text = "取消"
	dialog.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen())
			dialog.set_input_as_handled())
	dialog.file_selected.connect(import_selected)
	refresh()

func select_category(value: String) -> void:
	category = value
	slot = "player_head" if category == "player" else "drone_patrol"
	refresh()

func refresh(message: String = "") -> void:
	host.clear_children(rows)
	var slots: Dictionary = NinjaSkins.ENTITY_SLOTS if category == "entities" else NinjaSkins.PART_LABELS
	for key in slots:
		var id: String = "player_" + key if category == "player" else key
		var text: String = slots[key] + ("  · 已替换" if skins.entries.has(id) else "")
		var b: Button = host.button(rows, text, Rect2(0, 0, 242, 37), func(): slot = id; refresh(), slot == id)
		b.custom_minimum_size = Vector2(242, 37)
		b.name = "Skin_" + id
	heading.text = NinjaSkins.PART_LABELS[slot.trim_prefix("player_")] if slot.begins_with("player_") else NinjaSkins.ENTITY_SLOTS[slot]
	detail.text = skins.entries[slot].title if skins.entries.has(slot) else "使用默认图形"
	preview.slot = slot
	layout_button.visible = category == "player"
	layout_button.disabled = skins.texture(slot) == null
	notice.text = message if not message.is_empty() else ("图片保持原比例。点击「关节与比例」设置连接点、显示尺寸和偏移。\n模型大小与关节独立于碰撞箱；修改自动保存。" if category == "player" else "选择对象后导入 PNG、JPG 或 WebP，自动裁切透明留白并等比缩放。\n贴图只改变外观，不改变碰撞箱；导入后自动保存本地副本。")

func open_import() -> void:
	selected_file_slot = slot
	dialog.popup_centered(Vector2i(800, 580))

func import_selected(path: String) -> void:
	var result := skins.import_file(selected_file_slot, path)
	refresh(result.message)

func edit_layout() -> void:
	if skins.texture(slot) == null: return
	rig_editor = NinjaRigEditor.new()
	rig_editor.host = host
	rig_editor.skins = skins
	rig_editor.part = slot.trim_prefix("player_")
	add_child(rig_editor)
	rig_editor.popup_centered()
