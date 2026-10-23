class_name NinjaPresetScreen
extends Window
var host: Node
var skins: NinjaSkins
var parent_screen: Control
var selector := OptionButton.new()
var name_field := LineEdit.new()
var status := RichTextLabel.new()
var current: Label
var library: Array[Dictionary]=[]
var file_dialog := FileDialog.new()
var exporting := false

func _ready() -> void:
	title="外观预设 / Appearance presets"; size=Vector2i(840,560); min_size=size
	transient=true; exclusive=true; theme=host.ui.theme
	close_requested.connect(queue_free)
	window_input.connect(func(event:InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen()); set_input_as_handled())
	var panel := Control.new(); add_child(panel)
	var bg := ColorRect.new(); bg.size=Vector2(size); bg.color=host.PAPER; panel.add_child(bg)
	host.label(panel,"完整外观预设 / Complete appearance presets",Vector2(28,20),Vector2(780,36),24)
	current=host.label(panel,"",Vector2(28,65),Vector2(780,30),15)
	selector.position=Vector2(28,110); selector.size=Vector2(500,38); panel.add_child(selector)
	selector.item_selected.connect(func(i:int): name_field.text=library[i].name)
	host.button(panel,"读取整包 / Load",Rect2(550,110,260,38),load_selected,true)
	name_field.position=Vector2(28,168); name_field.size=Vector2(500,38); name_field.placeholder_text="预设名称 / Preset name"; panel.add_child(name_field)
	host.button(panel,"新建副本 / New copy",Rect2(550,168,260,38),func(): save_named(true))
	host.label(panel,"新建：复制当前完整外观；读取：整体替换。\nNew copies include all defaults, textures, clips, joints and backgrounds.\nLoading replaces the complete appearance, including default slots.",Vector2(28,220),Vector2(500,75),14,host.MUTED)
	host.button(panel,"保存到此名称 / Save",Rect2(550,222,260,38),func(): save_named(false))
	host.button(panel,"导入包 / Import .nvskin",Rect2(28,310,240,38),func(): open_file(false))
	host.button(panel,"导出包 / Export .nvskin",Rect2(286,310,240,38),func(): open_file(true))
	status.position=Vector2(28,370); status.size=Vector2(780,115); status.selection_enabled=true; panel.add_child(status)
	status.add_theme_color_override("default_color",host.INK)
	host.button(panel,"完成 / Done",Rect2(650,505,160,36),queue_free)
	file_dialog.access=FileDialog.ACCESS_FILESYSTEM; file_dialog.filters=PackedStringArray(["*.nvskin ; NVLink full appearance preset"])
	file_dialog.theme=parent_screen.dialog.theme
	file_dialog.window_input.connect(func(event:InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen()); file_dialog.set_input_as_handled())
	file_dialog.file_selected.connect(file_selected); add_child(file_dialog)
	refresh()
	name_field.text=skins.preset_name

func refresh() -> void:
	current.text="当前工作包 / Working copy: "+skins.preset_name
	library=NinjaSkinPresets.list_presets(skins)
	selector.clear()
	for item in library:
		selector.add_item(item.name)
		if item.name==skins.preset_name: selector.select(selector.item_count-1)
	parent_screen.refresh()

func save_named(new_copy: bool) -> void:
	var result := NinjaSkinPresets.save_named(skins,name_field.text,new_copy)
	status.text=result.message
	if result.ok: refresh()

func load_selected() -> void:
	if selector.selected<0: return
	var result := NinjaSkinPresets.load_file(skins,library[selector.selected].path)
	status.text=result.message
	if result.ok: refresh(); name_field.text=skins.preset_name

func open_file(save_mode: bool) -> void:
	exporting=save_mode
	file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if save_mode else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir=skins.storage_root.path_join("presets")
	if save_mode: file_dialog.current_file=name_field.text.validate_filename()+".nvskin"
	file_dialog.popup_centered(Vector2i(760,480))

func file_selected(path: String) -> void:
	var result := NinjaSkinPresets.save_file(skins,path,name_field.text) if exporting else NinjaSkinPresets.load_file(skins,path)
	status.text=result.message
	if result.ok: refresh(); name_field.text=skins.preset_name
