class_name NinjaPRTSScreen
extends Window
var host: Node
var skins: NinjaSkins
var character := LineEdit.new()
var all_outfits := CheckButton.new()
var log_view := RichTextLabel.new()
var summary: Label
var start_button: Button
var fetcher := NinjaPRTSFetcher.new()
var running := false
var last_result: Dictionary={}
var target_directory := ""

func _ready() -> void:
	title="PRTS 资源抓取 / Resource download"; size=Vector2i(880,620); min_size=size
	transient=true; exclusive=true; theme=host.ui.theme
	close_requested.connect(func(): if not running: queue_free())
	window_input.connect(func(event:InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("n_fullscreen"):
			host.set_fullscreen(not host.window_mode.is_fullscreen()); set_input_as_handled())
	add_child(fetcher)
	var panel := Control.new(); add_child(panel)
	var bg := ColorRect.new(); bg.size=Vector2(size); bg.color=host.PAPER; panel.add_child(bg)
	host.label(panel,"PRTS 资源抓取 / Resource download",Vector2(28,20),Vector2(820,38),24)
	host.label(panel,"角色名或页面网址 / Character name or page URL",Vector2(28,70),Vector2(810,28),15)
	character.position=Vector2(28,104); character.size=Vector2(620,38); character.text="蕾缪安"; panel.add_child(character)
	start_button=host.button(panel,"开始 / Download",Rect2(668,104,180,38),start_download,true)
	all_outfits.position=Vector2(28,155); all_outfits.text="全部皮肤 / All outfits（默认仅默认皮肤 / default outfit only）"; panel.add_child(all_outfits)
	var root := ProjectSettings.globalize_path("res://..") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().get_base_dir()
	target_directory=root.path_join("sources/input pictures").simplify_path()
	if not OS.has_feature("editor") and not DirAccess.dir_exists_absolute(root.path_join("sources")):
		target_directory=OS.get_executable_path().get_base_dir().path_join("sources/input pictures")
	var destination: Label = host.label(panel,"保存 / Destination: "+target_directory,Vector2(28,200),Vector2(820,44),12,host.MUTED)
	destination.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	host.label(panel,"下载的是 Spine 原始模型，并不等于已导入动画。绑定动作请使用 GIF / MP4 / WebM。\nDownloads are raw Spine models. Use exported GIF / MP4 / WebM clips for gameplay animation.",Vector2(28,246),Vector2(820,45),13,host.MUTED)
	summary=host.label(panel,"等待开始 / Ready",Vector2(28,300),Vector2(820,55),15)
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	log_view.position=Vector2(28,365); log_view.size=Vector2(820,178); log_view.selection_enabled=true; log_view.scroll_following=true; panel.add_child(log_view)
	log_view.add_theme_color_override("default_color",host.INK)
	fetcher.progress.connect(func(message:String): log_view.append_text(message+"\n"))
	host.button(panel,"取消任务 / Cancel",Rect2(28,568,200,36),func(): fetcher.cancel())
	host.button(panel,"打开目录 / Open folder",Rect2(244,568,240,36),func():
		DirAccess.make_dir_recursive_absolute(target_directory)
		OS.shell_open(fetcher.output_directory if not fetcher.output_directory.is_empty() else target_directory))
	host.button(panel,"关闭 / Close",Rect2(668,568,180,36),func(): if not running: queue_free())

func start_download() -> void:
	if running: return
	running=true; start_button.disabled=true; character.editable=false; all_outfits.disabled=true
	log_view.clear(); summary.text="抓取中… / Downloading…"
	last_result=await fetcher.fetch_character(character.text,target_directory,"*" if all_outfits.button_pressed else "默认")
	summary.text=last_result.message.get_slice("\n",0)
	if not last_result.ok:
		for error in last_result.get("errors",[]): log_view.append_text(str(error.get("error","Unknown error"))+"\n")
	running=false; start_button.disabled=false; character.editable=true; all_outfits.disabled=false
