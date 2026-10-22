class_name NinjaSettings
extends RefCounted

var max_fps: int = 0
var vsync: bool = false
var acceleration: float = 1.0
var max_speed: float = NinjaBody.SPEED
var show_collisions := false
var map_zoom := 1.5
var fullscreen: bool = false
var volume: float = 0.45
var completed: Dictionary = {}
var best_times: Dictionary = {}
var last_episode: int = 0
var bindings: Dictionary = NinjaBindings.DEFAULTS.duplicate(true)
var path: String

func _init(test_mode: bool = false) -> void:
	var base := ProjectSettings.globalize_path("res://.local") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("userdata")
	path = base.path_join("test_settings.json" if test_mode else "settings.json")
	DirAccess.make_dir_recursive_absolute(base)
	if not test_mode and FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			max_fps = clampi(int(data.get("max_fps", 0)), 0, 1000)
			vsync = bool(data.get("vsync", false))
			acceleration = clampf(float(data.get("acceleration", 1.0)), 0.25, 4.0)
			max_speed = clampf(float(data.get("max_speed", NinjaBody.SPEED)), 60.0, 400.0)
			show_collisions = bool(data.get("show_collisions", false))
			map_zoom = clampf(float(data.get("map_zoom", 1.5)), 1, 4)
			fullscreen = bool(data.get("fullscreen", false))
			volume = clampf(float(data.get("volume", 0.45)), 0.0, 1.0)
			completed = data.get("completed", {})
			best_times = data.get("best_times", {})
			last_episode = clampi(int(data.get("last_episode", 0)), 0, 99)
			if data.get("bindings", {}) is Dictionary:
				bindings = NinjaBindings.normalized(data.get("bindings", {}))

func apply() -> void:
	Engine.max_fps = max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"format_version": 3, "max_fps": max_fps,
			"max_speed": max_speed, "show_collisions": show_collisions, "map_zoom": map_zoom,
			"vsync": vsync, "acceleration": acceleration, "fullscreen": fullscreen,
			"volume": volume, "completed": completed, "best_times": best_times,
			"last_episode": last_episode, "bindings": bindings}, "\t"))
