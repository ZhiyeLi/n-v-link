class_name NinjaMediaImporter
extends RefCounted
## Decode once on import. Gameplay only reads local PNG atlases, never video codecs.
static func decoder_path() -> String:
	return ProjectSettings.globalize_path("res://../sources/media_tools/ffmpeg.exe") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("tools/ffmpeg.exe")

static func convert(path: String, directory: String, background: bool = false) -> Dictionary:
	if not FileAccess.file_exists(decoder_path()): return {"ok":false,"message":"缺少 tools/ffmpeg.exe，请使用完整便携包。"}
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null or source.get_length() > 128*1024*1024: return {"ok":false,"message":"文件无法读取，或超过 128 MB。"}
	source.close()
	var fps := 12 if background else 24
	var limit := 96 if background else 288
	var size := Vector2i(512,384) if background else Vector2i(192,192)
	var id := "clips/" + str(Time.get_ticks_usec())
	var folder := directory.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	var output: Array = []
	var args := PackedStringArray(["-nostdin","-v","error","-y","-protocol_whitelist","file,pipe","-threads","2","-i",path,
		"-map","0:v:0","-an","-sn","-filter_threads","1","-vf","fps="+str(fps)+",scale=512:512:force_original_aspect_ratio=decrease",
		"-frames:v",str(limit+1),"-pix_fmt","rgba",folder.path_join("frame-%04d.png")])
	var code := OS.execute(decoder_path(), args, output, true, false)
	var files := DirAccess.get_files_at(folder)
	files.sort()
	if code != 0 or files.is_empty() or files.size() > limit:
		cleanup(folder)
		return {"ok":false,"message":"解码失败或动画过长。单位动画限 12 秒，背景动画限 8 秒；请先裁剪。"}
	# Use one union crop for the entire clip: frame-by-frame cropping causes jitter.
	var crop := Rect2i()
	var dimensions := Vector2i.ZERO
	for file in files:
		var img := Image.load_from_file(folder.path_join(file))
		if img == null: cleanup(folder); return {"ok":false,"message":"动画帧损坏。"}
		dimensions = img.get_size()
		var used := img.get_used_rect()
		if used.has_area(): crop = crop.merge(used) if crop.has_area() else used
	if not crop.has_area(): cleanup(folder); return {"ok":false,"message":"动画完全透明。"}
	if background: crop = Rect2i(Vector2i.ZERO, dimensions)
	var columns := 2048 / size.x
	var capacity := columns * (2048 / size.y)
	var sheets: Array[String] = []
	for start in range(0,files.size(),capacity):
		var count := mini(capacity,files.size()-start)
		var atlas := Image.create(columns*size.x,ceili(float(count)/columns)*size.y,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for index in range(count):
			var img := Image.load_from_file(folder.path_join(files[start+index])).get_region(crop)
			img.convert(Image.FORMAT_RGBA8)
			var ratio := minf(float(size.x)/img.get_width(),float(size.y)/img.get_height())
			if background: ratio = maxf(float(size.x)/img.get_width(),float(size.y)/img.get_height())
			img.resize(maxi(1,roundi(img.get_width()*ratio)),maxi(1,roundi(img.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
			var tile := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
			tile.fill(Color.TRANSPARENT)
			tile.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),(size-img.get_size())/2)
			atlas.blit_rect(tile,Rect2i(Vector2i.ZERO,size),Vector2i(index%columns,index/columns)*size)
		var name := "atlas-"+str(sheets.size())+".png"
		if atlas.save_png(folder.path_join(name)) != OK: cleanup(folder); return {"ok":false,"message":"无法写入动画。"}
		sheets.append(name)
	for file in files: DirAccess.remove_absolute(folder.path_join(file))
	var manifest := {"version":1,"fps":fps,"count":files.size(),"size":[size.x,size.y],"columns":columns,"capacity":capacity,"sheets":sheets}
	var file := FileAccess.open(folder.path_join("clip.json"),FileAccess.WRITE)
	if file == null: cleanup(folder); return {"ok":false,"message":"无法保存动画索引。"}
	file.store_string(JSON.stringify(manifest))
	file.close()
	return {"ok":true,"file":id+"/clip.json","title":path.get_file(),"frames":files.size(),"fps":fps,
		"message":"已导入动画：%s · %d 帧 / %d FPS" % [path.get_file(),files.size(),fps]}

static func cleanup(folder: String) -> void:
	# Only the unique flat conversion directory created by this class is removed.
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
