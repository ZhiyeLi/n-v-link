class_name NinjaAnimation
extends RefCounted
## Numeric joint markers recovered from the supplied N 1.4 animation timeline.
## 72 run frames / 64.8 world pixels; air frames 85..103 follow vertical speed.
static var frames: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/n14_animation.json")).frames
const ARM := 3.9
const LEG := 5.8

static func markers(frame: float, wrap_run: bool = false) -> Dictionary:
	var index := int(floorf(frame))
	var next := index + 1
	if wrap_run and next > 84: next = 13
	var a: Dictionary = frames[clampi(index - 1, 0, 103)]
	var b: Dictionary = frames[clampi(next - 1, 0, 103)]
	var result := {}
	for key in a:
		result[key] = Vector2(a[key][0], a[key][1]).lerp(Vector2(b[key][0], b[key][1]), fposmod(frame, 1.0))
	return result

static func make_pose(stance: String, cycle: float, speed: float, vertical: float, wall_side: float) -> Dictionary:
	var frame := 1.0
	match stance:
		"run": frame = 13 + fposmod(cycle, TAU) / TAU * 72
		"skid": frame = 12
		"takeoff", "wall_jump": frame = 85
		"rise", "fall", "air":
			frame = 94 + 9 * (clampf(vertical / 40, -1, 0) if vertical < 0 else sqrt(clampf(vertical / 100, 0, 1)))
		"wall_climb", "wall_slide": frame = 104
	var m := markers(frame, stance == "run")
	if stance in ["wall_climb", "wall_slide"]:
		for key in m: m[key].x *= wall_side
		if stance == "wall_climb":
			# Reaching upward while still carrying jump momentum, not powered climbing.
			m.handL.y += 1.2 * sin(cycle)
			m.handR.y -= 1.2 * sin(cycle)
			m.footL.y -= 1.5
			m.pelvis.y -= 0.6
		else:
			m.handL.y += 0.3 * sin(cycle * 2)
	elif stance == "wall_jump":
		m.footR = Vector2(wall_side * 8.5, 3.2)
		m.handL = Vector2(-wall_side * 4.8, -6.5)
		m.shoulder.x -= wall_side * 1.5
	elif stance == "idle":
		m.shoulder.y += sin(cycle * 0.4) * 0.10
	var hip: Vector2 = m.pelvis
	var shoulder: Vector2 = m.shoulder
	var up := (shoulder - hip).normalized()
	var joints := {"hip": hip, "shoulder": shoulder, "head": shoulder + up * 3.4}
	joints.nose = joints.head + Vector2.RIGHT
	for side in ["left", "right"]:
		var suffix := "L" if side == "left" else "R"
		var foot: Vector2 = m["foot" + suffix]
		var foot_direction := Vector2(1.5, 0)
		if stance in ["wall_climb", "wall_slide"]: foot_direction = Vector2(wall_side * 1.4, -0.4)
		elif stance in ["rise", "takeoff", "wall_jump"]: foot_direction = Vector2(1.0, 1.0)
		var arm := solve_limb(shoulder, m["hand" + suffix], ARM, ARM, -wall_side if stance.begins_with("wall_") else -1.0)
		var leg := solve_limb(hip, foot - foot_direction, LEG, LEG, wall_side if stance.begins_with("wall_") else 1.0)
		joints[side + "_elbow"] = arm[0]
		joints[side + "_hand"] = arm[1]
		joints[side + "_knee"] = leg[0]
		joints[side + "_ankle"] = leg[1]
		joints[side + "_toe"] = leg[1] + foot_direction
	return joints

static func solve_limb(origin: Vector2, target: Vector2, upper: float, lower: float, bend: float) -> Array[Vector2]:
	var delta := target - origin
	var distance := clampf(delta.length(), 0.1, upper + lower - 0.03)
	var direction := delta.normalized()
	if direction == Vector2.ZERO: direction = Vector2.DOWN
	var along := (upper * upper - lower * lower + distance * distance) / (2 * distance)
	var side := Vector2(direction.y, -direction.x) * bend
	return [origin + direction * along + side * sqrt(maxf(0, upper * upper - along * along)), origin + direction * distance]
