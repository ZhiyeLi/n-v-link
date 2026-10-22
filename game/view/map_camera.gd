class_name NinjaMapCamera
extends RefCounted
## Render policy only: all coordinates are map/world pixels, never physics state.
const MAP_SIZE := Vector2(792, 600)
var mode := "follow"
var zoom := 1.5
var center := MAP_SIZE / 2
var fixed_center := MAP_SIZE / 2
var targets: Array[Vector2] = []
var provider := Callable()
var initialized := false
var smoothing := 12.0
var actual_zoom := 1.5

func configure(options: Dictionary) -> void:
	if options.has("mode") and options.mode in ["follow", "fixed", "group", "custom"]: mode = options.mode
	if options.has("zoom"): zoom = clampf(float(options.zoom), 1, 4)
	if options.has("center"): fixed_center = options.center
	if options.has("smoothing"): smoothing = maxf(0, options.smoothing)
	if options.get("snap", false): initialized = false

func update(dt: float, player: Vector2) -> Rect2:
	var desired := player
	var desired_zoom := zoom
	var group_bounds := Rect2()
	if mode == "fixed": desired = fixed_center
	elif mode == "group" and not targets.is_empty():
		var box := Rect2(targets[0], Vector2.ZERO)
		for point in targets: box = box.expand(point)
		box = box.grow(60)
		group_bounds = box
		desired = box.get_center()
		desired_zoom = clampf(minf(MAP_SIZE.x / box.size.x, MAP_SIZE.y / box.size.y), 1, zoom)
	elif mode == "custom" and provider.is_valid():
		var result = provider.call({"player": player, "targets": targets.duplicate(), "delta": dt, "map_size": MAP_SIZE})
		if result is Dictionary:
			desired = result.get("center", player)
			desired_zoom = clampf(float(result.get("zoom", zoom)), 1, 4)
	if not desired.is_finite(): desired = player
	var amount := 1.0 if not initialized or smoothing == 0 else 1 - exp(-smoothing * dt)
	center = center.lerp(desired, amount)
	actual_zoom = lerpf(actual_zoom, desired_zoom, amount)
	if mode == "group" and not targets.is_empty():
		# Zoom out promptly to keep participants visible; zoom in smoothly.
		actual_zoom = minf(actual_zoom, desired_zoom)
		var visible_half := MAP_SIZE / (actual_zoom * 2)
		var low := group_bounds.end - visible_half
		var high := group_bounds.position + visible_half
		center.x = clampf(center.x, low.x, high.x) if low.x <= high.x else MAP_SIZE.x / 2
		center.y = clampf(center.y, low.y, high.y) if low.y <= high.y else MAP_SIZE.y / 2
	var half := MAP_SIZE / (actual_zoom * 2)
	center = center.clamp(half, MAP_SIZE - half)
	initialized = true
	return Rect2(center - half, half * 2)

func transform_for(rect: Rect2) -> Transform2D:
	var factor := MAP_SIZE / rect.size
	return Transform2D(0, factor, 0, -rect.position * factor)
