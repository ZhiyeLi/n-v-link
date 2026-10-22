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

func _init(base: String = "") -> void:
	if base.is_empty():
		base = ProjectSettings.globalize_path("res://.local") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("userdata")
	directory = base.path_join("skins")
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest := directory.path_join("skins.json")
	if FileAccess.file_exists(manifest):
		var data = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if data is Dictionary:
			for slot in data:
				if valid_slot(slot) and data[slot] is Dictionary:
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

func ensure_layout(slot: String) -> void:
	if not slot.begins_with("player_") or texture(slot) == null: return
	if layout.is_empty(): layout = {"version": 1, "scale": 1.0, "motion": 1.0, "parts": {}}
	var part := slot.trim_prefix("player_")
	if not layout.parts.has(part): layout.parts[part] = NinjaRigLayout.defaults(part, Rect2(texture(slot).get_image().get_used_rect()))

func set_layout_value(part: String, key: String, value: float) -> void:
	ensure_layout("player_" + part)
	if layout.is_empty() or not layout.parts.has(part) or not NinjaRigLayout.LIMITS.has(key): return
	var bounds: Array = NinjaRigLayout.LIMITS[key]
	layout.parts[part][key] = clampf(value, bounds[0], bounds[1])
	save()

static func valid_slot(slot: String) -> bool:
	return ENTITY_SLOTS.has(slot) or (slot.begins_with("player_") and PART_LABELS.has(slot.trim_prefix("player_")))

static func canvas_size(slot: String) -> Vector2i:
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
	ensure_layout(slot)
	save()
	return {"ok": true, "message": "已导入并归一化：%s → %d × %d" % [title, normalized.get_width(), normalized.get_height()]}

func remove(slot: String) -> void:
	entries.erase(slot)
	textures.erase(slot)
	if slot.begins_with("player_") and layout.has("parts"): layout.parts.erase(slot.trim_prefix("player_"))
	save()

func reset_all() -> void:
	entries.clear()
	textures.clear()
	layout.clear()
	save()

func save() -> void:
	var file := FileAccess.open(directory.path_join("skins.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(entries, "\t"))
	var layout_file := FileAccess.open(directory.path_join("layout.json"), FileAccess.WRITE)
	if layout_file: layout_file.store_string(JSON.stringify(layout, "\t"))
	revision += 1
	changed.emit()

func texture(slot: String) -> Texture2D:
	return textures.get(slot)

func apply_rig(rig: NinjaRig) -> void:
	rig.layout = layout.duplicate(true)
	for part in NinjaRig.PARTS: rig.set_part_texture(part, texture("player_" + part))

func install_demo() -> Dictionary:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_skins/manifest.json"))
	if not manifest is Dictionary: return {"ok": false, "message": "测试资源缺失。"}
	for slot in manifest.slots:
		var image := (load("res://data/demo_skins/" + str(manifest.slots[slot])) as Texture2D).get_image()
		var result := install_image(slot, image, "能天使" if slot.begins_with("player_") else "源石虫")
		if not result.ok: return result
	layout = manifest.get("layout", {}).duplicate(true)
	save()
	return {"ok": true, "message": "已应用能天使角色部件与源石虫定轨无人机测试贴图。"}
