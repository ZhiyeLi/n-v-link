extends SceneTree
func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://../build/licenses")
	DirAccess.make_dir_recursive_absolute(folder)
	var license := FileAccess.open(folder.path_join("GODOT-LICENSE.txt"), FileAccess.WRITE)
	license.store_string(Engine.get_license_text())
	var third_party := FileAccess.open(folder.path_join("GODOT-THIRD-PARTY.json"), FileAccess.WRITE)
	third_party.store_string(JSON.stringify({"licenses": Engine.get_license_info(), "copyrights": Engine.get_copyright_info()}, "\t"))
	quit()
