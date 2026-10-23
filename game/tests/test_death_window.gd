extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
func tap(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.settings = NinjaSettings.new(true)
	main.settings.path = ProjectSettings.globalize_path("res://.local/v052-window.json")
	main.settings.max_fps = 60
	root.add_child(main)
	for i in range(5): await process_frame
	main.start_episode(0)
	tap(KEY_R)
	check(main.state=="dead" and main.sim.ragdoll.active,"R enters death through real window input")
	for i in range(8): await process_frame
	check(main.sim.ragdoll.age>0.05,"Death continues animating")
	tap(KEY_R)
	check(main.state=="dead","Second R does not reload level")
	tap(KEY_ENTER)
	check(main.state=="playing" and main.sim.ninja.alive,"Enter restarts level")
	main.settings.bindings.retry=[KEY_X,0,0]
	NinjaBindings.install(main.settings.bindings)
	tap(KEY_R)
	check(main.state=="playing","Old binding is removed")
	tap(KEY_X)
	check(main.state=="dead","Remapped suicide key works")
	main.free()
	print("WINDOW_TEST_RESULT: ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
