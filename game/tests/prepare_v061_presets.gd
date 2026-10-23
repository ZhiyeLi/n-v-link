extends SceneTree
func require(result: Dictionary) -> void:
	if not result.ok: printerr(result.message); quit(1)
func _initialize() -> void:
	var base := ProjectSettings.globalize_path("res://.local/factory-presets-"+str(Time.get_ticks_usec()))
	var skins := NinjaSkins.new(base)
	var out := ProjectSettings.globalize_path("res://data/presets")
	skins.reset_all()
	require(NinjaSkinPresets.save_file(skins,out.path_join("default.nvskin"),"默认 / Default"))
	skins.install_demo(); skins.install_v06_demo()
	require(NinjaSkinPresets.save_file(skins,out.path_join("iengtv.nvskin"),"i能tv"))
	skins.reset_all()
	var source := ProjectSettings.globalize_path("res://data/preset_assets/char_204_platnm")
	for part in NinjaRig.PARTS:
		require(skins.install_image("player_"+part,Image.load_from_file(source.path_join("player_"+part+".png")),"白金 / Platinum"))
	skins.layout=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("layout.json")))
	require(skins.install_image("drone_patrol",(load("res://data/demo_skins/drone_patrol.png") as Texture2D).get_image(),"源石虫 / Originium Slug"))
	var clip_folder := skins.directory.path_join("clips/nearl")
	DirAccess.make_dir_recursive_absolute(clip_folder)
	for file in ["clip.json","sheet_0.png"]:
		var output := FileAccess.open(clip_folder.path_join(file),FileAccess.WRITE)
		output.store_buffer(FileAccess.get_file_as_bytes("res://data/preset_assets/nearl_clip/"+file)); output.close()
	for state in ["move","dash"]:
		require(skins.install_clip("drone_scout@"+state,{"ok":true,"file":"clips/nearl/clip.json","title":"临光 / Nearl · N run retarget","message":"installed"}))
	skins.set_playback("drone_scout@dash",1.65,true)
	skins.appearance.drone_scout_scale=1.75
	skins.save()
	require(NinjaSkinPresets.save_file(skins,out.path_join("platinum_nearl.nvskin"),"白金·临光"))
	print("FACTORY_PRESETS_READY: default, i能tv, 白金·临光")
	quit()
