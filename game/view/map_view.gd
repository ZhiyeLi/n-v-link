class_name NinjaMapView
extends SubViewportContainer
## Public camera interface, independent of single/multiplayer simulation.
var camera := NinjaMapCamera.new()
var viewport: SubViewport
var world: Node2D
var visible_rect := Rect2(Vector2.ZERO, NinjaMapCamera.MAP_SIZE)

func _ready() -> void:
	size = NinjaMapCamera.MAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(NinjaMapCamera.MAP_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	add_child(viewport)
	viewport.add_child(world)

func set_view_policy(options: Dictionary, callback: Callable = Callable()) -> void:
	camera.configure(options)
	if callback.is_valid(): camera.provider = callback

func set_targets(points: Array) -> void:
	camera.targets.clear()
	for point in points:
		if point is Vector2 and point.is_finite(): camera.targets.append(point)

func reset_follow() -> void:
	camera.configure({"mode": "follow", "snap": true})

func _process(dt: float) -> void:
	if world.sim == null or not world.visible: return
	var fraction := 1.0 if world.paused else Engine.get_physics_interpolation_fraction()
	var player: Vector2 = world.sim.ninja.previous_pos.lerp(world.sim.ninja.pos, fraction)
	visible_rect = camera.update(dt, player)
	viewport.canvas_transform = camera.transform_for(visible_rect)
