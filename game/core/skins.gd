class_name NinjaSkins
extends RefCounted
signal changed
## Portable, local PNG copies. Appearance never changes physics dimensions.
const ENTITY_SLOTS := {
	"drone_patrol": "定轨无人机", "drone_scout": "侦察无人机", "drone_laser": "激光无人机", "drone_chain": "机枪无人机",
	"guard": "地面守卫", "thwump": "冲撞方块", "bounce": "弹性方块", "mine": "地雷",
	"gold": "金块", "turret": "炮塔", "rocket_base": "导弹发射器", "rocket": "追踪导弹", "pad": "弹射器"}
const PART_LABELS := {"head": "头部", "body": "躯干", "left_upper_arm": "左大臂", "left_forearm": "左小臂",
	"right_upper_arm": "右大臂", "right_forearm": "右小臂", "left_thigh": "左大腿", "left_calf": "左小腿",
	"left_foot": "左脚", "right_thigh": "右大腿", "right_calf": "右小腿", "right_foot": "右脚"}
const ENTITY_SIZES := {"drone_patrol": Vector2(22, 22), "drone_scout": Vector2(22, 24), "drone_laser": Vector2(22, 22),
	"drone_chain": Vector2(22, 22), "guard": Vector2(16, 12), "thwump": Vector2(18, 18), "bounce": Vector2(19.2, 19.2),
	"mine": Vector2(11, 11), "gold": Vector2(6, 6), "turret": Vector2(16, 16), "rocket_base": Vector2(14, 14),
	"rocket": Vector2(12, 7), "pad": Vector2(16, 14)}
var directory := ""
var entries: Dictionary = {}
var textures: Dictionary = {}
var revision := 0
var layout: Dictionary = {}
var clips: Dictionary = {}
var appearance: Dictionary = {}
var storage_root := ""
var preset_name := "当前外观 / Current appearance"

func _init(base: String = "") -> void:
	if base.is_empty():
		base = ProjectSettings.globalize_path("res://.local") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("userdata")
	storage_root=base
	directory = base.path_join("skins")
	var pointer_path := base.path_join("active_skin.json")
	if FileAccess.file_exists(pointer_path):
		var pointer = JSON.parse_string(FileAccess.get_file_as_string(pointer_path))
		if pointer is Dictionary and str(pointer.get("directory","")).begins_with("preset_working/") and NinjaSkinPresets.safe_relative(pointer.directory):
			var active: String=base.path_join(pointer.directory)
			if FileAccess.file_exists(active.path_join("bundle.json")):
				directory=active; preset_name=str(pointer.get("name",preset_name))
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest := directory.path_join("skins.json")
	if FileAccess.file_exists(manifest):
		var data = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if data is Dictionary:
			for slot in data:
				if valid_slot(slot) and data[slot] is Dictionary:
					if data[slot].get("kind", "") == "clip":
						if load_clip(slot, data[slot]): entries[slot] = data[slot]
						continue
					var path := directory.path_join(slot + ".png")
					if FileAccess.file_exists(path):
						var img := Image.load_from_file(path)
						if img != null and not img.is_empty():
							entries[slot] = data[slot]
							textures[slot] = ImageTexture.create_from_image(img)
	var layout_path := directory.path_join("layout.json")
	if FileAccess.file_exists(layout_path):
		var value = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
		if value is Dictionary and value.get("parts", {}) is Dictionary: layout = value
	if layout.is_empty() and not textures.is_empty():
		# The bundled 0.4 example uses the same images. Adopt its newly measured
		# anchors automatically; leave user-imported images and their data intact.
		var demo := true
		for part in PART_LABELS:
			if entries.get("player_" + part, {}).get("title", "") != "能天使": demo = false
		var bundled = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_skins/manifest.json"))
		if demo and bundled is Dictionary and bundled.has("layout"): layout = bundled.layout.duplicate(true)
		else:
			for slot in textures:
				if slot.begins_with("player_"): ensure_layout(slot)
		save()
	var appearance_path := directory.path_join("appearance.json")
	if FileAccess.file_exists(appearance_path):
		var value = JSON.parse_string(FileAccess.get_file_as_string(appearance_path))
		if value is Dictionary: appearance = value
	NinjaSkinFixes.apply(self)

func ensure_layout(slot: String) -> void:
	if not PART_LABELS.has(slot.trim_prefix("player_")) or texture(slot) == null: return
	if layout.is_empty(): layout = {"version": 1, "scale": 1.0, "motion": 1.0, "parts": {}}
	var part := slot.trim_prefix("player_")
	if not layout.get("enabled",true):
		layout.parts[part]=NinjaRigLayout.defaults(part,Rect2(texture(slot).get_image().get_used_rect()))
		layout.enabled=true
	if not layout.parts.has(part): layout.parts[part] = NinjaRigLayout.defaults(part, Rect2(texture(slot).get_image().get_used_rect()))

func set_layout_value(part: String, key: String, value: float) -> void:
	ensure_layout("player_" + part)
	if layout.is_empty() or not layout.parts.has(part) or not NinjaRigLayout.LIMITS.has(key): return
	var bounds: Array = NinjaRigLayout.LIMITS[key]
	layout.parts[part][key] = clampf(value, bounds[0], bounds[1])
	save()

static func valid_slot(slot: String) -> bool:
	if slot.contains("@"):
		var pieces := slot.split("@")
		return pieces.size() == 2 and NinjaSkinStates.SLOTS.get(pieces[0], []).has(pieces[1])
	if slot in ["background", "player_actor"]: return true
	return ENTITY_SLOTS.has(slot) or (slot.begins_with("player_") and PART_LABELS.has(slot.trim_prefix("player_")))

static func canvas_size(slot: String) -> Vector2i:
	if slot.get_slice("@",0) == "background": return Vector2i(792,600)
	if slot.contains("@") or slot == "player_actor": return Vector2i(192,192)
	if slot == "player_head": return Vector2i(192, 192)
	if slot.begins_with("player_"): return Vector2i(256, 128)
	var size: Vector2 = ENTITY_SIZES.get(slot, Vector2.ONE)
	return Vector2i((size * (256.0 / maxf(size.x, size.y))).round())

static func normalize(source: Image, target: Vector2i) -> Image:
	if source == null or source.is_empty(): return null
	var input := source.duplicate() as Image
	input.convert(Image.FORMAT_RGBA8)
	var used := input.get_used_rect()
	if used.size.x == 0 or used.size.y == 0: return null
	input = input.get_region(used)
	var ratio := minf(float(target.x) / input.get_width(), float(target.y) / input.get_height())
	input.resize(maxi(1, roundi(input.get_width() * ratio)), maxi(1, roundi(input.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var result := Image.create(target.x, target.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	result.blit_rect(input, Rect2i(Vector2i.ZERO, input.get_size()), (target - input.get_size()) / 2)
	return result

func import_file(slot: String, path: String) -> Dictionary:
	if not valid_slot(slot): return {"ok": false, "message": "请选择有效的贴图对象。"}
	if path.get_extension().to_lower() in ["gif","mp4","webm"]:
		if slot.begins_with("player_") and not slot.begins_with("player_actor"):
			return {"ok":false,"message":"完整动图请导入「角色动画」，分部位骨架仍使用静态图片。"}
		return install_clip(slot,NinjaMediaImporter.convert(path,directory,slot.begins_with("background")))
	if not path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
		return {"ok": false, "message": "支持 PNG、JPG 和 WebP。透明贴图请使用 PNG 或 WebP。"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "message": "无法打开这张图片，请检查文件是否仍在原位置。"}
	if file.get_length() > 24 * 1024 * 1024: return {"ok": false, "message": "单张图片请小于 24 MB。"}
	var img := Image.load_from_file(path)
	if img == null or img.is_empty(): return {"ok": false, "message": "图片无法解码，请换一张有效图片。"}
	if img.get_width() > 8192 or img.get_height() > 8192: return {"ok": false, "message": "图片单边请不超过 8192 像素。"}
	return install_image(slot, img, path.get_file())

func install_image(slot: String, img: Image, title: String) -> Dictionary:
	if not valid_slot(slot): return {"ok": false, "message": "未知对象。"}
	var normalized := normalize(img, canvas_size(slot))
	if normalized == null: return {"ok": false, "message": "图片完全透明，没有可显示的内容。"}
	var error := normalized.save_png(directory.path_join(slot + ".png"))
	if error != OK: return {"ok": false, "message": "无法保存贴图副本，请检查工作区写入权限。"}
	entries[slot] = {"title": title, "source_size": [img.get_width(), img.get_height()], "normalized_size": [normalized.get_width(), normalized.get_height()]}
	textures[slot] = ImageTexture.create_from_image(normalized)
	clips.erase(slot)
	if slot.begins_with("player_") and not slot.begins_with("player_actor"): ensure_layout(slot)
	save()
	return {"ok": true, "message": "已导入并归一化：%s → %d × %d" % [title, normalized.get_width(), normalized.get_height()]}

func remove(slot: String) -> void:
	entries.erase(slot)
	textures.erase(slot)
	clips.erase(slot)
	if slot.begins_with("player_") and layout.has("parts"): layout.parts.erase(slot.trim_prefix("player_"))
	save()

func reset_all() -> void:
	entries.clear()
	textures.clear()
	clips.clear()
	layout.clear()
	appearance={"v06_examples":true}
	save()

func save() -> void:
	var file := FileAccess.open(directory.path_join("skins.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(entries, "\t"))
	var layout_file := FileAccess.open(directory.path_join("layout.json"), FileAccess.WRITE)
	if layout_file: layout_file.store_string(JSON.stringify(layout, "\t"))
	var appearance_file := FileAccess.open(directory.path_join("appearance.json"),FileAccess.WRITE)
	if appearance_file: appearance_file.store_string(JSON.stringify(appearance,"\t"))
	NinjaSkinPresets.write_working(self)
	revision += 1
	changed.emit()

func texture(slot: String) -> Texture2D:
	if clips.has(slot): return clips[slot].frames[0]
	return textures.get(slot)

func install_clip(slot: String, result: Dictionary) -> Dictionary:
	if not valid_slot(slot): return {"ok":false,"message":"未知动画槽。"}
	if not result.get("ok",false): return result
	var entry := {"kind":"clip","file":result.file,"title":result.title,"speed":1.0,"loop":true}
	if not load_clip(slot,entry): return {"ok":false,"message":"动画索引损坏，未替换原动画。"}
	entries[slot] = entry
	textures.erase(slot)
	save()
	return result

func load_clip(slot: String, entry: Dictionary) -> bool:
	var relative: String = entry.get("file","")
	if relative.is_absolute_path() or ".." in relative or not relative.begins_with("clips/"): return false
	var path := directory.path_join(relative)
	var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not data is Dictionary: return false
	if int(data.get("count",0)) < 1 or int(data.count)>288 or float(data.get("fps",0))<=0: return false
	if not data.get("size",[]) is Array or data.size.size()!=2: return false
	var dimensions := Vector2i(int(data.size[0]),int(data.size[1]))
	if dimensions.x<=0 or dimensions.y<=0 or dimensions.x>512 or dimensions.y>512: return false
	var columns := int(data.get("columns",0))
	var capacity := int(data.get("capacity",0))
	if columns<1 or capacity<1: return false
	var pages: Array[Texture2D] = []
	for name in data.get("sheets",[]):
		if not name is String or name != name.get_file(): return false
		var image := Image.load_from_file(path.get_base_dir().path_join(name))
		if image == null or image.get_width()>2048 or image.get_height()>2048: return false
		pages.append(ImageTexture.create_from_image(image))
	if pages.size()*capacity<int(data.count): return false
	var frames: Array[Texture2D] = []
	for index in range(int(data.count)):
		var frame := AtlasTexture.new()
		frame.atlas = pages[index/capacity]
		frame.region = Rect2(Vector2i((index%capacity)%columns,(index%capacity)/columns)*dimensions,dimensions)
		frames.append(frame)
	clips[slot] = {"frames":frames,"fps":float(data.fps)}
	return true

func animation_key(slot: String, state: String) -> String:
	if slot == "player_actor" and state == "death":
		return slot+"@death" if textures.has(slot+"@death") or clips.has(slot+"@death") else ""
	for key in [slot+"@"+state, slot+"@move", slot+"@idle", slot]:
		if textures.has(key) or clips.has(key): return key
	return ""

func frame_at(slot: String, state: String, age: float) -> Texture2D:
	var key := animation_key(slot,state)
	if not clips.has(key): return textures.get(key)
	var clip: Dictionary = clips[key]
	var entry: Dictionary = entries.get(key,{})
	var index := maxi(0,floori(age*clip.fps*clampf(float(entry.get("speed",1)),0.1,4.0)))
	index = index % clip.frames.size() if entry.get("loop",true) else mini(index,clip.frames.size()-1)
	return clip.frames[index]

func set_playback(key: String, speed: float, loop: bool) -> void:
	if not entries.has(key): return
	entries[key].speed = clampf(speed,0.1,4.0)
	entries[key].loop = loop
	save()

func visual_scale(slot: String) -> float:
	return clampf(float(appearance.get(slot+"_scale",1.0)),0.25,6.0)

func default_input_directory() -> String:
	var base := ProjectSettings.globalize_path("res://..") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().get_base_dir()
	var preferred := base.path_join("sources/input pictures")
	return preferred if DirAccess.dir_exists_absolute(preferred) else OS.get_executable_path().get_base_dir()

func install_v06_demo(only_missing: bool = false) -> Dictionary:
	var base := "res://data/demo_v06/"
	if not FileAccess.file_exists(base+"manifest.json"): return {"ok":false,"message":"0.6 示例资源尚未打包。"}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(base+"manifest.json"))
	for slot in manifest.slots:
		if only_missing and (entries.has(slot) or entries.has(slot.get_slice("@",0))): continue
		var spec: Dictionary = manifest.slots[slot]
		if spec.kind == "image":
			var image := (load(base+spec.file) as Texture2D).get_image()
			install_image(slot,image,spec.title)
		else:
			var clip = JSON.parse_string(FileAccess.get_file_as_string(base+spec.file))
			var source_folder: String = (base+spec.file).get_base_dir()
			var relative := "clips/demo_texas/clip.json"
			var folder := directory.path_join(relative).get_base_dir()
			DirAccess.make_dir_recursive_absolute(folder)
			for sheet in clip.sheets:
				var image := (load(source_folder.path_join(sheet)) as Texture2D).get_image()
				image.save_png(folder.path_join(sheet))
			var file := FileAccess.open(folder.path_join("clip.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify(clip)); file.close()
			install_clip(slot,{"ok":true,"file":relative,"title":spec.title,"message":"示例已应用。"})
			set_playback(slot,float(spec.get("speed",1.0)),true)
	if not only_missing or not appearance.has("drone_scout_scale"): appearance.drone_scout_scale=1.75
	if not only_missing or not appearance.has("drone_laser_scale"): appearance.drone_laser_scale=1.75
	appearance.v06_examples=true
	save()
	return {"ok":true,"message":"已应用 Texas 移动 / 加速复用冲刺，以及蕾缪安静态后备外观。"}

func apply_rig(rig: NinjaRig) -> void:
	rig.layout = layout.duplicate(true) if layout.get("enabled",true) else {}
	for part in NinjaRig.PARTS: rig.set_part_texture(part, texture("player_" + part))

func install_demo() -> Dictionary:
	for key in entries.keys():
		if key.begins_with("player_actor"): remove(key)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_skins/manifest.json"))
	if not manifest is Dictionary: return {"ok": false, "message": "测试资源缺失。"}
	for slot in manifest.slots:
		var image := (load("res://data/demo_skins/" + str(manifest.slots[slot])) as Texture2D).get_image()
		var result := install_image(slot, image, "能天使" if slot.begins_with("player_") else "源石虫")
		if not result.ok: return result
	layout = manifest.get("layout", {}).duplicate(true)
	save()
	return {"ok": true, "message": "已应用能天使角色部件与源石虫定轨无人机测试贴图。"}
