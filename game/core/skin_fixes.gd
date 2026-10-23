class_name NinjaSkinFixes
extends RefCounted
## Repair only the shipped 0.6.1 artwork, retaining user anchors, timing and other skins.
const OLD_PACKAGE := "adc9a14a1e896dce118ec68082811ddc0119ca727ab30e1a8806a177e2eefcd2"
const PLATINUM_HEAD := "f73322d05b02714783edf3e689b3851a610bd4a37dfcc8680abf966f81d47b51"
const OLD_NEARL_SHEET := "4ec97e76558c4af730e7b6498eb537c852776e6156e3c6460589b099e317e2cb"

static func apply(skins) -> void:
	var changed := false
	var head: Dictionary=skins.layout.get("parts",{}).get("head",{})
	var head_path: String=skins.directory.path_join("player_head.png")
	if skins.textures.has("player_head") and head.get("layer",0)==8 and FileAccess.get_sha256(head_path)==PLATINUM_HEAD:
		head.layer=1
		changed=true
	var replaced := false
	for slot in skins.clips:
		var entry: Dictionary=skins.entries.get(slot,{})
		var relative: String=entry.get("file","")
		var clip = JSON.parse_string(FileAccess.get_file_as_string(skins.directory.path_join(relative)))
		if not clip is Dictionary: continue
		for sheet in clip.get("sheets",[]):
			var path: String=skins.directory.path_join(relative.get_base_dir().path_join(sheet))
			if FileAccess.get_sha256(path)!=OLD_NEARL_SHEET: continue
			var zip := ZIPReader.new()
			if zip.open("res://data/presets/platinum_nearl.nvskin")!=OK: continue
			var bytes := zip.read_file("clips/nearl/sheet_0.png"); zip.close()
			if bytes.is_empty(): continue
			var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
			if file==null: continue
			file.store_buffer(bytes); file.close()
			if DirAccess.rename_absolute(path+".tmp",path)==OK: replaced=true
	# Move and dash can share one atlas but each keeps its own loaded frames.
	if replaced:
		for slot in skins.clips: skins.load_clip(slot,skins.entries[slot])
	if changed or replaced: skins.save()
