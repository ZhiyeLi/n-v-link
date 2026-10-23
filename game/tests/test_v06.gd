extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var base := ProjectSettings.globalize_path("res://.local/v06-tests")
	var skins := NinjaSkins.new(base)
	skins.reset_all()
	var source := ProjectSettings.globalize_path("res://../sources/input pictures")
	var gif := ""
	for file in DirAccess.get_files_at(source):
		if file.ends_with(".gif"): gif=source.path_join(file)
	check(not gif.is_empty(),"User Texas GIF is present")
	var result := skins.import_file("drone_scout@move",gif)
	check(result.ok,"GIF decode and Unicode/spaces path import")
	if not result.ok: printerr(result); quit(1); return
	var clip: Dictionary=skins.clips["drone_scout@move"]
	check(clip.frames.size()==46,"Texas duration preserved at 24 fps")
	check(skins.frame_at("drone_scout","move",0)!=skins.frame_at("drone_scout","move",0.5),"GIF advances instead of showing its first frame forever")
	check(skins.frame_at("drone_scout","dash",0.5)==skins.frame_at("drone_scout","move",0.5),"Missing dash falls back to movement")
	check(skins.frame_at("drone_scout","move",0)==skins.frame_at("drone_scout","move",46.0/24),"Loop wraps at clip duration")
	skins.set_playback("drone_scout@move",2,false)
	check(skins.frame_at("drone_scout","move",100)==clip.frames.back(),"One-shot clips hold last frame")
	var reload := NinjaSkins.new(base)
	check(reload.clips.has("drone_scout@move") and reload.entries["drone_scout@move"].speed==2,"Animation and playback settings survive restart")
	check(reload.frame_at("player_actor","death",0)==null,"Missing death animation preserves physical ragdoll")
	var mp4 := base.path_join("test video.mp4")
	var output: Array=[]
	var code := OS.execute(NinjaMediaImporter.decoder_path(),PackedStringArray(["-nostdin","-y","-v","error","-f","lavfi","-i","testsrc2=size=96x64:rate=24","-t","0.5","-c:v","mpeg4",mp4]),output,true,false)
	check(code==0,"MP4 fixture creation")
	check(skins.import_file("drone_laser@fire",mp4).ok,"MP4 import uses same animation path")
	check(skins.clips["drone_laser@fire"].frames.size()==12,"MP4 duration retained")
	check(skins.import_file("background@idle",mp4).ok,"Animated background import")
	check(skins.frame_at("background","idle",0).get_size()==Vector2(512,384),"Background decoded at bounded resolution")
	var image := Image.create(160,80,false,Image.FORMAT_RGBA8); image.fill(Color.CORNFLOWER_BLUE)
	check(skins.install_image("background",image,"Background").ok,"Static background import")
	check(not skins.valid_slot("drone_scout@bogus") and not skins.valid_slot("../escape@move"),"Unknown and path-shaped animation slots rejected")
	var previous: Texture2D = skins.frame_at("drone_laser","fire",0)
	var invalid := base.path_join("broken.mp4")
	var bad := FileAccess.open(invalid,FileAccess.WRITE); bad.store_string("broken"); bad.close()
	check(not skins.import_file("drone_laser@fire",invalid).ok,"Malformed movie rejected")
	check(skins.frame_at("drone_laser","fire",0)==previous,"Failed conversion preserves existing animation")
	var pack := base.path_join("one-character")
	DirAccess.make_dir_recursive_absolute(pack)
	image.save_png(pack.path_join("某干员-默认-正面-Idle.png"))
	DirAccess.copy_absolute(gif,pack.path_join("某干员-默认-基建-Move.gif"))
	var plan := NinjaSkinPack.scan(pack,"player_actor")
	check(plan.matches.has("run") and plan.matches.has("idle") and plan.missing.has("蹬墙"),"Generic operator names map actions and report missing actions")
	check(NinjaSkinPack.scan(source,"player_actor").has("error"),"Different operators cannot be silently mixed")
	var e := {"type":6,"p":[0,0,0,1,0,0],"state":0,"chasing":false}
	check(NinjaSkinStates.state(e)=="move","Scout movement state")
	e.chasing=true
	check(NinjaSkinStates.state(e)=="dash","Scout pursuit selects separate dash slot")
	e.p[4]=1
	for state in [0,2,3,4]:
		e.state=state
		check(NinjaSkinStates.state(e)=={0:"move",2:"charge",3:"fire",4:"cooldown"}[state],"Laser animation follows attack phase")
	check(skins.install_v06_demo().ok and skins.clips.has("drone_scout@dash") and skins.texture("drone_laser")!=null,"Bundled Texas and Lemuen install")
	var main = load("res://scenes/main.tscn").instantiate()
	main.settings=NinjaSettings.new(true); main.settings.path=base.path_join("settings.json"); main.skins=skins
	root.add_child(main); main.set_physics_process(false)
	main.show_skins()
	main.skin_screen.select_category("actor")
	check(main.skin_screen.state_picker.item_count==9,"Player animation editor exposes eight action slots and base")
	main.skin_screen.select_category("entities"); main.skin_screen.slot="drone_scout"; main.skin_screen.refresh()
	check(main.skin_screen.state_picker.item_count==3,"Scout editor exposes movement and dash")
	main.skin_screen.state_picker.select(1); main.skin_screen.refresh_selection()
	check(main.skin_screen.import_key()=="drone_scout@move","UI imports into the chosen action slot")
	main.skin_screen.selected_file_slot="drone_scout@dash"
	await main.skin_screen.import_selected(mp4)
	check(skins.clips["drone_scout@dash"].frames.size()==12 and not main.skin_screen.busy,"Actual UI movie conversion completes on worker")
	main.show_menu(); main.start_episode(0)
	await process_frame
	check(main.world.terrain_view.background!=null,"Gameplay renders custom background")
	var before: Dictionary = main.sim.configuration()
	skins.install_image("player_actor@idle",image,"Whole actor")
	await process_frame
	check(main.world.actor.visible and not main.world.rig.visible,"Whole-character clip replaces rig without splitting source image")
	check(main.sim.configuration()==before,"Appearance never modifies gameplay configuration")
	main.world.paused=true
	var age: float=main.world.animation_time
	await process_frame
	check(main.world.animation_time==age,"Pause freezes presentation clocks")
	main.queue_free()
	await process_frame
	print("V06_TEST_RESULT: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
