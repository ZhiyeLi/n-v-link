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
var state_picker: OptionButton
var playback: SpinBox
var looping: CheckButton
var visual_size: SpinBox
var pack_dialog: FileDialog
var busy := false
var worker: Thread
var selected_pack_slot := ""

func _ready() -> void:
	size = Vector2(1024, 768)
	panel = Panel.new()
	panel.position = Vector2(56, 32)
	panel.size = Vector2(912, 704)
	panel.add_theme_stylebox_override("panel", host.box(host.PAPER, 10))
	add_child(panel)
	host.label(panel, "自定义贴图", Vector2(30, 22), Vector2(310, 42), 28)
	host.button(panel,"外观预设",Rect2(370,25,150,37),open_presets)
	host.button(panel,"PRTS 抓取",Rect2(540,25,170,37),open_prts)
	host.button(panel, "返回首页", Rect2(755, 25, 127, 37), func(): if not busy: host.show_menu())
	host.button(panel, "场景实体", Rect2(30, 82, 125, 36), func(): select_category("entities"))
	host.button(panel, "角色部位", Rect2(166, 82, 125, 36), func(): select_category("player"))
	host.button(panel, "角色动画", Rect2(30, 125, 125, 36), func(): select_category("actor"))
	host.button(panel, "地图背景", Rect2(166, 125, 125, 36), func(): select_category("background"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 174)
	scroll.size = Vector2(262, 380)
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	heading = host.label(panel, "", Vector2(328, 82), Vector2(548, 32), 21)
	layout_button = host.button(panel, "关节与比例…", Rect2(700, 82, 155, 35), edit_layout)
	detail = host.label(panel, "", Vector2(328, 161), Vector2(548, 28), 13, host.MUTED)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview = NinjaSkinPreview.new()
	preview.skins = skins
	var frame := Control.new()
	frame.position = Vector2(328, 190)
	frame.size = Vector2(480, 260)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	frame.add_child(preview)
	preview.scale = Vector2(0.9,0.85)
	state_picker = OptionButton.new()
	state_picker.position = Vector2(328,120)
	state_picker.size = Vector2(160,32)
	state_picker.item_selected.connect(func(_i: int): preview.age=0; refresh_selection())
	panel.add_child(state_picker)
	host.label(panel,"倍速",Vector2(500,125),Vector2(40,25),12)
	playback = SpinBox.new()
	playback.position=Vector2(540,120); playback.size=Vector2(70,32)
	playback.min_value=0.1; playback.max_value=4; playback.step=0.1
	playback.value_changed.connect(func(value: float): skins.set_playback(import_key(),value,looping.button_pressed))
	panel.add_child(playback)
	looping=CheckButton.new(); looping.text="循环"; looping.position=Vector2(617,120)
	looping.toggled.connect(func(value: bool): skins.set_playback(import_key(),playback.value,value))
	panel.add_child(looping)
	host.label(panel,"大小",Vector2(720,125),Vector2(40,25),12)
	visual_size=SpinBox.new(); visual_size.position=Vector2(760,120); visual_size.size=Vector2(80,32)
	visual_size.min_value=0.25; visual_size.max_value=6; visual_size.step=0.05
	visual_size.value_changed.connect(func(value: float): skins.appearance[slot+"_scale"]=value; skins.save())
	panel.add_child(visual_size)
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
	host.button(panel, "导入图片 / 动画…", Rect2(328, 510, 220, 42), open_import, true)
	host.button(panel, "清空当前槽", Rect2(562, 510, 220, 42), func(): if not busy: skins.remove(import_key()); refresh("已清空当前槽。"))
	host.button(panel,"自动匹配动作文件夹…",Rect2(328,559,220,38),open_pack)
	host.button(panel,"应用 Texas / 蕾缪安",Rect2(562,559,220,38),func(): if not busy: refresh(skins.install_v06_demo().message))
	notice = host.label(panel, "", Vector2(30, 562), Vector2(280, 59), 12, host.MUTED)
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	host.button(panel, "应用两个测试用例", Rect2(30, 625, 210, 40), func():
		var result := skins.install_demo()
		refresh(result.message))
	host.button(panel, "恢复全部默认", Rect2(252, 625, 157, 40), func(): skins.reset_all(); refresh("已恢复全部默认贴图。"))
	host.label(panel, "素材：PRTS / 用户提供 · 明日方舟\n原图版权归鹰角网络及关联权利人。", Vector2(454, 623), Vector2(425, 42), 12, host.MUTED)
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
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.gif,*.mp4,*.webm ; 图片 / GIF / MP4 / WebM"])
	dialog.current_dir = skins.default_input_directory()
	add_child(dialog)
	dialog.get_ok_button().text = "导入"
	dialog.get_cancel_button().text = "取消"
	dialog.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen())
			dialog.set_input_as_handled())
	dialog.file_selected.connect(import_selected)
	pack_dialog=FileDialog.new(); pack_dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR
	pack_dialog.access=FileDialog.ACCESS_FILESYSTEM; pack_dialog.theme=picker_theme
	pack_dialog.title="选择一个角色的动作文件夹"; pack_dialog.current_dir=skins.default_input_directory()
	pack_dialog.dir_selected.connect(import_pack)
	pack_dialog.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen()); pack_dialog.set_input_as_handled())
	add_child(pack_dialog)
	refresh()

func select_category(value: String) -> void:
	category = value
	slot = {"player":"player_head","entities":"drone_patrol","actor":"player_actor","background":"background"}[category]
	refresh()

func refresh(message: String = "") -> void:
	host.clear_children(rows)
	var slots: Dictionary = NinjaSkins.ENTITY_SLOTS if category == "entities" else (NinjaSkins.PART_LABELS if category == "player" else {slot:"整套角色动画" if category == "actor" else "地图背景"})
	for key in slots:
		var id: String = "player_" + key if category == "player" else key
		var text: String = slots[key] + ("  · 已替换" if skins.entries.has(id) else "")
		var b: Button = host.button(rows, text, Rect2(0, 0, 242, 37), func(): slot = id; refresh(), slot == id)
		b.custom_minimum_size = Vector2(242, 37)
		b.name = "Skin_" + id
	heading.text = slots[slot.trim_prefix("player_")] if category == "player" else slots[slot]
	preview.slot = slot
	var previous: String = state_picker.get_item_metadata(state_picker.selected) if state_picker.selected >= 0 else "base"
	state_picker.clear()
	for state in ["base"]+NinjaSkinStates.SLOTS.get(slot,[]):
		state_picker.add_item(NinjaSkinStates.LABELS[state]); state_picker.set_item_metadata(state_picker.item_count-1,state)
		if state == previous: state_picker.select(state_picker.item_count-1)
	refresh_selection()
	layout_button.visible = category == "player"
	layout_button.disabled = skins.texture(slot) == null
	notice.text = message if not message.is_empty() else "先选对象及动作槽，再导入素材。\n缺少动作时回退到移动、待机或静态贴图。"

func import_key() -> String:
	var state: String = state_picker.get_item_metadata(state_picker.selected) if state_picker.selected >= 0 else "base"
	return slot if state == "base" else slot+"@"+state

func refresh_selection() -> void:
	var key := import_key()
	var entry: Dictionary = skins.entries.get(key,{})
	detail.text=entry.get("title","此槽未设置 · 使用后备外观")
	preview.anim_state=key.get_slice("@",1)
	playback.set_value_no_signal(float(entry.get("speed",1)))
	looping.set_pressed_no_signal(entry.get("loop",true))
	visual_size.set_value_no_signal(skins.visual_scale(slot))
	playback.editable=skins.clips.has(key); looping.disabled=not skins.clips.has(key)

func open_import() -> void:
	if busy: return
	selected_file_slot = import_key()
	dialog.popup_centered(Vector2i(800, 580))

func import_selected(path: String) -> void:
	if busy: return
	busy=true
	var result: Dictionary = await import_asset(selected_file_slot,path)
	busy=false
	refresh(result.message)

func import_asset(key: String, path: String) -> Dictionary:
	if path.get_extension().to_lower() not in ["gif","mp4","webm"]: return skins.import_file(key,path)
	if key.begins_with("player_") and not key.begins_with("player_actor"): return {"ok":false,"message":"完整动画请使用「角色动画」分类。"}
	notice.text="正在转换动画，请稍候…"
	worker=Thread.new()
	var error := worker.start(NinjaMediaImporter.convert.bind(path,skins.directory,key.begins_with("background")))
	if error!=OK: worker=null; return {"ok":false,"message":"无法启动动画转换。"}
	while worker.is_alive(): await get_tree().process_frame
	var result: Dictionary = worker.wait_to_finish()
	worker=null
	return skins.install_clip(key,result)

func open_pack() -> void:
	if busy: return
	if not NinjaSkinStates.SLOTS.has(slot): notice.text="文件夹导入用于完整角色或实体动画。"; return
	selected_pack_slot=slot
	pack_dialog.popup_centered(Vector2i(800,580))

func import_pack(folder: String) -> void:
	if busy: return
	busy=true
	var plan := NinjaSkinPack.scan(folder,selected_pack_slot)
	if plan.has("error"): busy=false; refresh(plan.error); return
	var count := 0
	var errors: Array[String] = []
	for state in plan.matches:
		var result: Dictionary = await import_asset(selected_pack_slot+"@"+state,plan.matches[state])
		if result.ok: count+=1
		else: errors.append(result.message)
	busy=false
	refresh("已导入 %d 个动作。缺少：%s%s" % [count,"、".join(plan.missing),"；"+"；".join(errors) if not errors.is_empty() else ""])

func _exit_tree() -> void:
	if worker != null and worker.is_started(): worker.wait_to_finish()

func edit_layout() -> void:
	if skins.texture(slot) == null: return
	rig_editor = NinjaRigEditor.new()
	rig_editor.host = host
	rig_editor.skins = skins
	rig_editor.part = slot.trim_prefix("player_")
	add_child(rig_editor)
	rig_editor.popup_centered()

func open_presets() -> void:
	if busy: return
	var window := NinjaPresetScreen.new()
	window.host=host; window.skins=skins; window.parent_screen=self
	add_child(window); window.popup_centered()

func open_prts() -> void:
	if busy: return
	var window := NinjaPRTSScreen.new()
	window.host=host; window.skins=skins
	add_child(window); window.popup_centered()
