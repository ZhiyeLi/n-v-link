class_name NinjaRigLayout
extends RefCounted
## Image anchors are measured on the visible, cropped image. Never stretch a bone image.
const LIMITS := {"width": [0.2, 80.0], "pivot_x": [-1.0, 2.0], "pivot_y": [-1.0, 2.0],
	"tip_x": [-1.0, 2.0], "tip_y": [-1.0, 2.0], "offset_x": [-40.0, 40.0], "offset_y": [-40.0, 40.0], "angle": [-180.0, 180.0]}
static var rest: Dictionary = NinjaAnimation.make_pose("idle", 0, 0, 0, 1)

static func defaults(part: String, region: Rect2) -> Dictionary:
	var max_side := 10.0 if part == "head" else (8.0 if part == "body" else (6.0 if "thigh" in part or "calf" in part else 4.5))
	var width := max_side * region.size.x / maxf(1, maxf(region.size.x, region.size.y))
	var tall := region.size.y > region.size.x
	return {"width": width, "pivot_x": 0.5 if tall or part == "head" else 0.12,
		"pivot_y": 0.85 if part in ["body", "head"] else (0.12 if tall else 0.5),
		"tip_x": 0.8 if part == "head" else (0.5 if tall else 0.88),
		"tip_y": 0.85 if part == "head" else (0.15 if part == "body" else (0.88 if tall else 0.5)),
		"offset_x": 3.4 if part == "head" else 0.0, "offset_y": 0.0, "angle": 0.0}

static func image_size(config: Dictionary, region: Rect2, scale: float = 1) -> Vector2:
	var width: float = config.width * scale
	return Vector2(width, width * region.size.y / maxf(1, region.size.x))

static func anchor(config: Dictionary, key: String) -> Vector2:
	return Vector2(config[key + "_x"], config[key + "_y"])

static func arrange(pose: Dictionary, profile: Dictionary, parts: Dictionary, stance: String = "idle") -> Dictionary:
	var result := {}
	var factor: float = profile.get("scale", 1.0)
	var strength: float = profile.get("motion", 1.0)
	var custom: Dictionary = profile.get("parts", {})
	for key in NinjaRig.PARTS:
		var ends: Array = NinjaRig.ENDS[key]
		var source_start: Vector2 = pose[ends[0]]
		var source_end: Vector2 = pose[ends[1]]
		var source_angle := (source_end - source_start).angle()
		var part: NinjaPart = parts[key]
		var config: Dictionary = custom.get(key, defaults(key, part.texture_region))
		var angle: float = source_angle + deg_to_rad(config.get("angle", 0))
		if config.has("reference_angle"):
			var rest_angle: float = (rest[ends[1]] - rest[ends[0]]).angle()
			angle = config.reference_angle + wrapf(source_angle - rest_angle, -PI, PI) * strength + deg_to_rad(config.get("angle", 0))
			if (stance.begins_with("wall_") or stance in ["rise", "fall", "takeoff", "air"]) and key not in ["body", "head"]:
				# Air and wall contacts need a directional reach, not a standing
				# pose offset. Retarget the N limb angles to the calibrated lengths.
				angle = source_angle + deg_to_rad(config.get("angle", 0))
			if stance == "run" and key not in ["body", "head", "left_foot", "right_foot"]:
				# A setup pose is asymmetric, not a locomotion reference. Applying
				# its per-limb offsets to a run folds one leg and keeps the other
				# extended. Use the authored run directions on the calibrated
				# lengths; keep the shoe's calibrated flat orientation.
				angle = source_angle + deg_to_rad(config.get("angle", 0))
		var length := source_start.distance_to(source_end) * factor
		if part.texture != null:
			var size := image_size(config, part.texture_region, factor)
			length = maxf(0.1, ((anchor(config, "tip") - anchor(config, "pivot")) * size).length())
		var start := source_start
		var parent: String = NinjaRig.PARENTS[key]
		if not parent.is_empty():
			start = result[parent].start if key.ends_with("thigh") else result[parent].end
			start += Vector2(config.offset_x, config.offset_y).rotated(result[parent].angle) * factor
		result[key] = {"start": start, "end": start + Vector2.from_angle(angle) * length, "angle": angle, "length": length, "config": config}
	# Keep the soles at the animation's authored height; the head/model may
	# extend outside the gameplay circle, which remains entirely independent.
	var shift := Vector2(0, maxf(pose.left_toe.y, pose.right_toe.y) - maxf(result.left_foot.end.y, result.right_foot.end.y))
	for value in result.values():
		value.start += shift
		value.end += shift
	return result
