extends SceneTree
var checks := 0
var failures: Array[String]=[]
var mode := "success"
var fetcher: NinjaPRTSFetcher
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr(message)
func _initialize() -> void: call_deferred("run")
func manifest(path: String) -> Dictionary:
	var zip := ZIPReader.new(); zip.open(path)
	var data: Dictionary=JSON.parse_string(zip.read_file("bundle.json").get_string_from_utf8()); zip.close()
	return data
func corrupt(source: String,dest: String,kind: String) -> void:
	var input := ZIPReader.new(); input.open(source)
	var data: Dictionary=JSON.parse_string(input.read_file("bundle.json").get_string_from_utf8())
	if kind=="missing": data.slots.erase("guard")
	elif kind=="hash": data.files["defaults/n14_animation.json"]="00"
	elif kind=="path": data.files["../escape.png"]="00"
	elif kind=="rig": data.layout.parts.head.width="bad"
	var output := ZIPPacker.new(); output.open(dest)
	for file in input.get_files():
		output.start_file(file)
		output.write_file(JSON.stringify(data).to_utf8_buffer() if file=="bundle.json" else input.read_file(file)); output.close_file()
	output.close(); input.close()
func fixture(url: String) -> Dictionary:
	await process_frame
	if mode=="cancel": fetcher.cancel(); return {"ok":false,"error":"Cancelled"}
	if mode=="network": return {"ok":false,"error":"HTTP 403"}
	if mode=="partial" and url.ends_with(".png"): return {"ok":false,"error":"HTTP 404"}
	var content := ""
	if url.contains("/w/"): content='<div id="spine-root" data-id="char_148_nearl"></div>' if mode!="missing-index" else "missing"
	elif url.ends_with("meta.json"):
		content=JSON.stringify({"prefix":"https://torappu.prts.wiki/assets/test/","skin":{"默认":{"正面":{"file":"char_148_nearl"}}}})
		if mode=="bad-index": content='{"prefix":"https://torappu.prts.wiki/","skin":{"默认":3}}'
	elif url.ends_with(".atlas"): content="char_148_nearl.png\nsize: 32,32\n"
	else: content="fixture bytes"
	return {"ok":true,"bytes":content.to_utf8_buffer()}

func check_layer_upgrade(base: String) -> void:
	var legacy := "res://tests/fixtures/platinum_nearl_layers_v061.nvskin"
	var folder := base.path_join("legacy/skins"); DirAccess.make_dir_recursive_absolute(folder)
	var zip := ZIPReader.new(); zip.open(legacy)
	for path in zip.get_files():
		if path.ends_with("/"): continue
		DirAccess.make_dir_recursive_absolute(folder.path_join(path).get_base_dir())
		var output := FileAccess.open(folder.path_join(path),FileAccess.WRITE)
		output.store_buffer(zip.read_file(path)); output.close()
	zip.close()
	var data := manifest(legacy); var entries := {}
	for slot in data.slots:
		if data.slots[slot].get("kind","")!="builtin": entries[slot]=data.slots[slot]
	data.layout.parts.head.offset_x=7.5
	entries["drone_scout@dash"].speed=2.25; entries["drone_scout@dash"].loop=false
	for pair in [["skins.json",entries],["layout.json",data.layout],["appearance.json",data.appearance]]:
		var output := FileAccess.open(folder.path_join(pair[0]),FileAccess.WRITE)
		output.store_string(JSON.stringify(pair[1])); output.close()
	var upgraded := NinjaSkins.new(base.path_join("legacy"))
	check(upgraded.layout.parts.head.layer==1 and upgraded.layout.parts.head.offset_x==7.5,"Existing Platinum working copy gets layer fix without resetting edited anchors")
	var updated := ZIPReader.new(); updated.open("res://data/presets/platinum_nearl.nvskin")
	var new_sheet := updated.read_file("clips/nearl/sheet_0.png"); updated.close()
	check(FileAccess.get_file_as_bytes(folder.path_join("clips/nearl/sheet_0.png"))==new_sheet,"Existing Nearl atlas receives body-over-legs fix")
	for state in ["move","dash"]:
		var atlas: Texture2D=upgraded.clips["drone_scout@"+state].frames[0].atlas
		var expected := Image.new(); expected.load_png_from_buffer(new_sheet)
		check(atlas.get_image().get_data()==expected.get_data(),"Shared Nearl atlas refreshed in memory for "+state)
	check(upgraded.entries["drone_scout@dash"].speed==2.25 and not upgraded.entries["drone_scout@dash"].loop,"Layer fix preserves user playback settings")
	var original_head := Image.create(16,16,false,Image.FORMAT_RGBA8); original_head.fill(Color.RED)
	upgraded.install_image("player_head",original_head,"User image"); upgraded.layout.parts.head.layer=8; upgraded.save()
	check(NinjaSkins.new(base.path_join("legacy")).layout.parts.head.layer==8,"Unrelated custom head is not migrated")
	var old_library := base.path_join("legacy/presets"); DirAccess.make_dir_recursive_absolute(old_library)
	DirAccess.copy_absolute(legacy,old_library.path_join("platinum_nearl.nvskin"))
	NinjaSkinPresets.ensure_library(upgraded)
	check(FileAccess.get_sha256(old_library.path_join("platinum_nearl.nvskin"))==FileAccess.get_sha256("res://data/presets/platinum_nearl.nvskin"),"Unmodified bundled preset is refreshed in an existing library")
	check(NinjaSkinPresets.load_file(upgraded,legacy).ok and upgraded.layout.parts.head.layer==1,"Importing an old complete package also gets the layer correction")

func run() -> void:
	var base := ProjectSettings.globalize_path("res://.local/v061-tests-"+str(Time.get_ticks_usec()))
	check_layer_upgrade(base)
	var skins := NinjaSkins.new(base)
	var library := NinjaSkinPresets.list_presets(skins)
	check(library.size()==3,"All factory packages are included")
	for item in library:
		var data := manifest(item.path)
		check(data.slots.size()==NinjaSkinPresets.all_slots().size(),"Full slot definition: "+item.name)
		check(data.layout.parts.size()==12 and data.files.has("defaults/n14_animation.json") and data.files.has("defaults/n14_drone_shapes.json"),"Defaults and every joint are packaged: "+item.name)
	var source := base.path_join("presets/iengtv.nvskin")
	check(NinjaSkinPresets.load_file(skins,source).ok,"Load i能tv")
	check(skins.entries.player_head.title=="能天使" and skins.clips.has("drone_scout@dash") and skins.texture("drone_laser")!=null,"Original preset contains every existing example")
	var source_hash := FileAccess.get_sha256(source)
	var original_working := skins.directory
	check(NinjaSkinPresets.save_named(skins,"独立副本",true).ok,"Create full copy")
	check(skins.directory!=original_working,"New preset has its own working assets")
	check(not NinjaSkinPresets.save_named(skins,"独立副本",true).ok,"Duplicate copy name refused")
	var img := Image.create(64,32,false,Image.FORMAT_RGBA8); img.fill(Color.DARK_BLUE)
	skins.install_image("background",img,"Test background")
	skins.install_image("guard@dash",img,"Test guard animation slot")
	skins.set_layout_value("head","offset_x",3.7)
	skins.appearance.drone_scout_scale=2.3; skins.set_playback("drone_scout@dash",2.25,false)
	check(NinjaSkinPresets.save_named(skins,"独立副本",false).ok,"Overwrite existing preset safely on Windows")
	check(FileAccess.get_sha256(source)==source_hash,"Editing copied preset leaves original package unchanged")
	var saved := ""
	for item in NinjaSkinPresets.list_presets(skins):
		if item.name=="独立副本": saved=item.path
	check(NinjaSkinPresets.load_file(skins,base.path_join("presets/platinum_nearl.nvskin")).ok,"Load Platinum/Nearl package")
	check(skins.entries.player_head.title.contains("白金") and skins.entries["drone_scout@move"].title.contains("临光"),"New preset uses requested characters")
	check(skins.texture("drone_patrol")!=null and skins.texture("drone_laser")==null,"Slug is present; old Lemuen override cleared")
	check(skins.texture("background")==null and skins.texture("guard@dash")==null and skins.visual_scale("drone_scout")==1.75,"Complete load clears extra background, action and size")
	check(NinjaSkinPresets.load_file(skins,saved).ok,"Reload modified complete snapshot")
	check(skins.texture("background")!=null and skins.texture("guard@dash")!=null,"Background and independent action restored")
	check(is_equal_approx(skins.layout.parts.head.offset_x,3.7) and skins.visual_scale("drone_scout")==2.3,"Rig and appearance restored")
	check(skins.entries["drone_scout@dash"].speed==2.25 and not skins.entries["drone_scout@dash"].loop,"Animation playback restored")
	var restarted := NinjaSkins.new(base)
	check(restarted.preset_name=="独立副本" and restarted.texture("background")!=null and restarted.clips.has("drone_scout@dash"),"Selected working package survives restart")
	for kind in ["missing","hash","path","rig"]:
		var corrupt_path := base.path_join("bad-"+kind+".nvskin"); corrupt(saved,corrupt_path,kind)
		var before := skins.directory
		check(not NinjaSkinPresets.load_file(skins,corrupt_path).ok and skins.directory==before and skins.texture("background")!=null,"Invalid "+kind+" package preserves active appearance")
	check(NinjaSkinPresets.load_file(skins,base.path_join("presets/default.nvskin")).ok,"Load complete default package")
	var rig := NinjaRig.new(); root.add_child(rig); skins.apply_rig(rig)
	check(skins.entries.is_empty() and skins.clips.is_empty() and rig.layout.is_empty(),"Default package restores unmodified original skeleton and visuals")
	var fixture_root := base.path_join("downloads")
	fetcher=NinjaPRTSFetcher.new(); root.add_child(fetcher); fetcher.transport=fixture
	var result := await fetcher.fetch_character("https://prts.wiki/w/临光#spine",fixture_root)
	check(result.ok and result.downloads.size()==3 and result.status=="success","Native downloader handles name, URL fragment and full success")
	var report_path := fetcher.output_directory.path_join("resources.json")
	check(FileAccess.file_exists(report_path) and FileAccess.file_exists(fetcher.output_directory.path_join(result.downloads[0].file)),"Downloader stores files and machine-readable report")
	for scenario in ["partial","network","missing-index","bad-index","cancel"]:
		mode=scenario
		result=await fetcher.fetch_character("临光",fixture_root)
		check(not result.ok and result.status==("partial" if scenario=="partial" else ("cancelled" if scenario=="cancel" else "failed")),"Visible outcome for "+scenario)
		check(not result.message.is_empty() and not result.errors.is_empty(),"Failure details for "+scenario)
	result=await fetcher.fetch_character("https://example.com/not-prts",fixture_root)
	check(not result.ok,"Non-PRTS address rejected")
	result=await fetcher.fetch_character("../outside",fixture_root)
	check(not result.ok,"Character input cannot escape resource folder")
	rig.queue_free(); fetcher.queue_free(); await process_frame
	print("V061_TEST_RESULT: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
