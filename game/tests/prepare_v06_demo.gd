extends SceneTree
func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../sources/input pictures")
	var dest := ProjectSettings.globalize_path("res://data/demo_v06")
	DirAccess.make_dir_recursive_absolute(dest)
	var gif := ""
	var lemuen := ""
	for file in DirAccess.get_files_at(source):
		if "德克萨斯" in file and file.ends_with(".gif"): gif=source.path_join(file)
		if "蕾缪安" in file and file.ends_with(".png"): lemuen=source.path_join(file)
	if gif.is_empty() or lemuen.is_empty(): printerr("Demo inputs missing"); quit(1); return
	var result := NinjaMediaImporter.convert(gif,dest)
	if not result.ok: printerr(result.message); quit(1); return
	var img := Image.load_from_file(lemuen)
	NinjaSkins.normalize(img,Vector2i(256,256)).save_png(dest.path_join("lemuen.png"))
	var data := {"slots":{
		"drone_scout@move":{"kind":"clip","file":result.file,"title":"Texas · Move"},
		"drone_scout@dash":{"kind":"clip","file":result.file,"title":"Texas · Move（加速复用）","speed":1.65},
		"drone_laser":{"kind":"image","file":"lemuen.png","title":"蕾缪安 · Idle（静态）"}}}
	var manifest := FileAccess.open(dest.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify(data,"\t")); manifest.close()
	print("V06_DEMO_READY: ",result.frames," frames")
	quit()
