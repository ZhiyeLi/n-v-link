class_name NinjaBindings
extends RefCounted

const ACTIONS := ["left", "right", "jump", "retry", "pause", "confirm", "fullscreen"]
const LABELS := {"left": "向左", "right": "向右", "jump": "跳跃", "retry": "自杀",
	"pause": "暂停 / 返回", "confirm": "下一关 / 确认", "fullscreen": "切换全屏"}
const DEFAULTS := {"left": [KEY_LEFT, KEY_A, 0], "right": [KEY_RIGHT, KEY_D, 0],
	"jump": [KEY_SHIFT, KEY_SPACE, KEY_Z], "retry": [KEY_R, 0, 0],
	"pause": [KEY_ESCAPE, 0, 0], "confirm": [KEY_ENTER, 0, 0], "fullscreen": [KEY_F11, 0, 0]}

static func normalized(data: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	var used := {}
	for action in ACTIONS:
		var values = data.get(action, DEFAULTS[action])
		if not values is Array: values = DEFAULTS[action]
		result[action] = [0, 0, 0]
		for slot in range(mini(3, values.size())):
			if not (values[slot] is int or values[slot] is float): continue
			var code := int(values[slot])
			if code <= 0 or code > KEY_UNKNOWN or used.has(code): continue
			result[action][slot] = code
			used[code] = true
	return result

static func install(bindings: Dictionary) -> void:
	release_actions()
	for action in ACTIONS:
		var name := StringName("n_" + action)
		if not InputMap.has_action(name): InputMap.add_action(name)
		InputMap.action_erase_events(name)
		for code in bindings[action]:
			if int(code) == 0: continue
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(name, event)

static func release_actions() -> void:
	NinjaInputFrame.pending_jump = false
	for action in ACTIONS:
		if InputMap.has_action("n_" + action): Input.action_release("n_" + action)

static func key_name(code: int) -> String:
	return "未绑定" if code == 0 else OS.get_keycode_string(code)

static func conflict(bindings: Dictionary, code: int, action: String, slot: int) -> String:
	for candidate in ACTIONS:
		for i in range(3):
			if candidate == action and i == slot: continue
			if int(bindings[candidate][i]) == code: return LABELS[candidate]
	return ""

static func primary_name(bindings: Dictionary, action: String) -> String:
	for code in bindings[action]:
		if int(code) != 0: return key_name(int(code))
	return "未绑定"
