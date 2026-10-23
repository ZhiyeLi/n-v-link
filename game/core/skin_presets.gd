class_name NinjaSkinPresets
extends RefCounted
## Self-contained snapshots. No parent presets, patch inheritance or external files.
const SCHEMA := 1
const DEFAULT_FILES := ["n14_animation.json","n14_drone_shapes.json"]

static func all_slots() -> Array[String]:
	var keys: Array[String] = []
	for key in NinjaSkins.ENTITY_SLOTS: keys.append(key)
	for key in NinjaSkins.PART_LABELS: keys.append("player_"+key)
	keys.append_array(["background","player_actor"])
	for base in NinjaSkinStates.SLOTS:
		for action in NinjaSkinStates.SLOTS[base]: keys.append(base+"@"+action)
	return keys

static func default_layout() -> Dictionary:
	var parts := {}
	for part in NinjaSkins.PART_LABELS: parts[part] = NinjaRigLayout.defaults(part,Rect2(0,0,1,1))
	return {"version":1,"scale":1.0,"motion":1.0,"parts":parts,"renderer":"n14-articulated","enabled":false}

static func complete_layout(layout: Dictionary) -> Dictionary:
	var result := default_layout()
	result.enabled=not layout.is_empty()
	for key in layout:
		if key != "parts": result[key]=layout[key]
	for key in layout.get("parts",{}):
		if result.parts.has(key): result.parts[key].merge(layout.parts[key],true)
	return result

static func snapshot(skins, name: String = "Working copy") -> Dictionary:
	var slots := {}
	for slot in all_slots(): slots[slot] = skins.entries[slot].duplicate(true) if skins.entries.has(slot) else {"kind":"builtin","renderer":"n14-default-v1"}
	var appearance := {"v06_examples":true}
	for slot in NinjaSkinStates.SLOTS: appearance[slot+"_scale"]=1.0
	appearance.merge(skins.appearance,true)
	return {"schema":SCHEMA,"name":name,"slots":slots,"layout":complete_layout(skins.layout),"appearance":appearance,
		"defaults":{"renderer":"n14-default-v1","animation":"defaults/n14_animation.json","drone_shapes":"defaults/n14_drone_shapes.json",
			"background":"c9c9d0","terrain_fill":"56565e","terrain_edge":"44444c","ninja_color":"282830"}}

static func write_working(skins) -> void:
	DirAccess.make_dir_recursive_absolute(skins.directory.path_join("defaults"))
	for name in DEFAULT_FILES:
		var path: String=skins.directory.path_join("defaults/"+name)
		if not FileAccess.file_exists(path):
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file: file.store_buffer(FileAccess.get_file_as_bytes("res://data/"+name))
	var file := FileAccess.open(skins.directory.path_join("bundle.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(snapshot(skins,skins.preset_name),"\t"))

static func safe_relative(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not ".." in path and not "\\" in path and not ":" in path

static func valid_layout(layout: Dictionary) -> bool:
	if not layout.get("parts") is Dictionary: return false
	for key in ["scale","motion"]:
		if not (layout.get(key) is float or layout.get(key) is int) or not is_finite(float(layout[key])): return false
	for part in NinjaSkins.PART_LABELS:
		if not layout.parts.get(part) is Dictionary: return false
		for key in NinjaRigLayout.LIMITS:
			var value = layout.parts[part].get(key)
			if not (value is float or value is int) or not is_finite(float(value)): return false
	return true

static func assets(skins) -> Array[String]:
	var files: Array[String] = ["defaults/n14_animation.json","defaults/n14_drone_shapes.json"]
	for slot in skins.entries:
		var entry: Dictionary=skins.entries[slot]
		if entry.get("kind","") == "clip":
			var path: String=entry.file
			if not files.has(path): files.append(path)
			var clip = JSON.parse_string(FileAccess.get_file_as_string(skins.directory.path_join(path)))
			if clip is Dictionary:
				for sheet in clip.sheets:
					var relative := path.get_base_dir().path_join(sheet)
					if not files.has(relative): files.append(relative)
		else: files.append(slot+".png")
	return files

static func save_file(skins, path: String, name: String) -> Dictionary:
	name=name.strip_edges()
	if name.is_empty() or name.length()>48: return {"ok":false,"message":"预设名称须为 1–48 个字符。 / Use a name of 1–48 characters."}
	write_working(skins)
	var manifest := snapshot(skins,name)
	manifest.files={}
	var files := assets(skins)
	for file in files:
		if not safe_relative(file) or not FileAccess.file_exists(skins.directory.path_join(file)):
			return {"ok":false,"message":"素材缺失，未保存："+file}
		manifest.files[file]=FileAccess.get_sha256(skins.directory.path_join(file))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp := path+".tmp"
	var zip := ZIPPacker.new()
	if zip.open(temp)!=OK: return {"ok":false,"message":"无法写入预设包。 / Cannot write preset."}
	var error := zip.start_file("bundle.json")
	if error==OK: error=zip.write_file(JSON.stringify(manifest,"\t").to_utf8_buffer())
	zip.close_file()
	for file in files:
		if error!=OK: break
		error=zip.start_file(file)
		if error==OK: error=zip.write_file(FileAccess.get_file_as_bytes(skins.directory.path_join(file)))
		zip.close_file()
	zip.close()
	if error!=OK: return {"ok":false,"message":"预设保存失败，原包保留。 / Save failed; old preset preserved."}
	if DirAccess.rename_absolute(temp,path)!=OK: return {"ok":false,"message":"无法替换预设包。 / Could not replace preset file."}
	return {"ok":true,"message":"已保存完整预设 / Saved complete preset: "+name,"path":path}

static func load_file(skins, path: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(path)!=OK: return {"ok":false,"message":"预设包无法打开。 / Cannot open preset."}
	var manifest = JSON.parse_string(zip.read_file("bundle.json").get_string_from_utf8())
	if not manifest is Dictionary or manifest.get("schema",0)!=SCHEMA or not manifest.get("slots") is Dictionary or not manifest.get("files") is Dictionary:
		zip.close(); return {"ok":false,"message":"预设格式错误，当前外观保留。 / Invalid preset; current appearance preserved."}
	for slot in all_slots():
		if not manifest.slots.has(slot) or not manifest.slots[slot] is Dictionary:
			zip.close(); return {"ok":false,"message":"不是全量预设：缺少 "+slot}
	if manifest.slots.size()!=all_slots().size() or not manifest.get("layout") is Dictionary or not manifest.get("appearance") is Dictionary:
		zip.close(); return {"ok":false,"message":"预设定义不完整。 / Incomplete preset definition."}
	if not valid_layout(manifest.layout) or not manifest.get("defaults") is Dictionary or manifest.defaults.get("renderer","")!="n14-default-v1":
		zip.close(); return {"ok":false,"message":"骨骼或默认资源版本无效。 / Invalid rig or default renderer version."}
	for slot in manifest.slots:
		if manifest.slots[slot].get("kind","") not in ["","image","clip","builtin"]:
			zip.close(); return {"ok":false,"message":"未知素材类型。 / Unknown asset type."}
	for file in DEFAULT_FILES:
		if not manifest.files.has("defaults/"+file): zip.close(); return {"ok":false,"message":"预设缺少默认资源。 / Default resources missing."}
	var id := "preset_working/"+str(Time.get_ticks_usec())
	var base: String=skins.storage_root.path_join(id)
	var directory := base.path_join("skins")
	DirAccess.make_dir_recursive_absolute(directory)
	var total := 0
	for file in manifest.files:
		if not safe_relative(file) or not zip.file_exists(file): zip.close(); return {"ok":false,"message":"预设文件路径无效或文件缺失。 / Invalid or missing asset."}
		var bytes := zip.read_file(file)
		total+=bytes.size()
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		if total>512*1024*1024 or hash.finish().hex_encode()!=manifest.files[file]:
			zip.close(); return {"ok":false,"message":"预设素材校验失败，当前外观保留。 / Asset verification failed; current appearance preserved."}
		var dest := directory.path_join(file)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var output := FileAccess.open(dest,FileAccess.WRITE)
		if output==null: zip.close(); return {"ok":false,"message":"无法复制预设素材。 / Cannot copy preset assets."}
		output.store_buffer(bytes); output.close()
	zip.close()
	var entries := {}
	for slot in manifest.slots:
		var entry: Dictionary=manifest.slots[slot]
		if entry.get("kind","") != "builtin":
			var file: String=entry.get("file","") if entry.get("kind","")=="clip" else slot+".png"
			if not manifest.files.has(file): return {"ok":false,"message":"预设引用了包外素材。 / External asset reference rejected."}
			entries[slot]=entry
	for pair in [["skins.json",entries],["layout.json",manifest.layout],["appearance.json",manifest.appearance],["bundle.json",manifest]]:
		var file := FileAccess.open(directory.path_join(pair[0]),FileAccess.WRITE)
		if file==null: return {"ok":false,"message":"无法写入工作包。 / Cannot write working copy."}
		file.store_string(JSON.stringify(pair[1])); file.close()
	var candidate := NinjaSkins.new(base)
	if candidate.entries.size()!=entries.size(): return {"ok":false,"message":"素材解码失败，当前外观保留。 / Asset decode failed; current appearance preserved."}
	# Commit only after every asset has been validated and decoded.
	var pointer := {"directory":id+"/skins","name":manifest.get("name","Preset")}
	var pointer_path: String=skins.storage_root.path_join("active_skin.json")
	var active := FileAccess.open(pointer_path+".tmp",FileAccess.WRITE)
	if active==null: return {"ok":false,"message":"无法保存预设选择。 / Cannot save active preset."}
	active.store_string(JSON.stringify(pointer)); active.close()
	if DirAccess.rename_absolute(pointer_path+".tmp",pointer_path)!=OK: return {"ok":false,"message":"无法切换预设。 / Cannot switch preset."}
	skins.directory=candidate.directory
	skins.entries=candidate.entries; skins.textures=candidate.textures; skins.clips=candidate.clips
	skins.layout=candidate.layout; skins.appearance=candidate.appearance; skins.preset_name=pointer.name
	skins.save()
	return {"ok":true,"message":"已完整读取 / Loaded full preset: "+str(pointer.name)}

static func ensure_library(skins) -> void:
	var directory: String=skins.storage_root.path_join("presets")
	DirAccess.make_dir_recursive_absolute(directory)
	for file in ["default.nvskin","iengtv.nvskin","platinum_nearl.nvskin"]:
		var bundled: String = "res://data/presets/"+file
		var outdated: bool = file=="platinum_nearl.nvskin" and FileAccess.file_exists(directory.path_join(file)) and FileAccess.get_sha256(directory.path_join(file))==NinjaSkinFixes.OLD_PACKAGE
		if FileAccess.file_exists(bundled) and (not FileAccess.file_exists(directory.path_join(file)) or outdated):
			var output := FileAccess.open(directory.path_join(file),FileAccess.WRITE)
			if output: output.store_buffer(FileAccess.get_file_as_bytes(bundled)); output.close()

static func list_presets(skins) -> Array[Dictionary]:
	ensure_library(skins)
	var result: Array[Dictionary]=[]
	var directory: String=skins.storage_root.path_join("presets")
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".nvskin"): continue
		var zip := ZIPReader.new()
		var path := directory.path_join(file)
		if zip.open(path)!=OK: continue
		var data = JSON.parse_string(zip.read_file("bundle.json").get_string_from_utf8()); zip.close()
		if data is Dictionary: result.append({"name":str(data.get("name",file)),"path":path})
	result.sort_custom(func(a,b): return a.name.naturalnocasecmp_to(b.name)<0)
	return result

static func save_named(skins, name: String, new_copy: bool) -> Dictionary:
	var found := ""
	for item in list_presets(skins):
		if item.name.nocasecmp_to(name.strip_edges())==0: found=item.path
	if new_copy and not found.is_empty(): return {"ok":false,"message":"名称已存在，请为副本取新名称。 / Name exists; choose a new copy name."}
	var path: String=found if not found.is_empty() else skins.storage_root.path_join("presets/"+name.strip_edges().sha256_text().substr(0,24)+".nvskin")
	var result := save_file(skins,path,name)
	if result.ok:
		var loaded := load_file(skins,path)
		if not loaded.ok: return loaded
	return result
