class_name NinjaWindowMode
extends RefCounted
## Only explicit fullscreen actions may change window mode or dimensions.
var previous_mode := DisplayServer.WINDOW_MODE_WINDOWED
var windowed_size := Vector2i(1024, 768)
var windowed_position := Vector2i.ZERO

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless" or enabled == is_fullscreen(): return
	if enabled:
		previous_mode = DisplayServer.window_get_mode()
		windowed_size = DisplayServer.window_get_size()
		windowed_position = DisplayServer.window_get_position()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(previous_mode)
		if previous_mode == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(windowed_size)
			DisplayServer.window_set_position(windowed_position)
