class_name NinjaRig
extends Node2D
## A 12-part articulated hierarchy. All poses share the same joints and skin slots.
const PARTS := ["body", "head", "left_upper_arm", "left_forearm", "right_upper_arm", "right_forearm",
	"left_thigh", "left_calf", "left_foot", "right_thigh", "right_calf", "right_foot"]
const PARENTS := {"body": "", "head": "body", "left_upper_arm": "body", "left_forearm": "left_upper_arm",
	"right_upper_arm": "body", "right_forearm": "right_upper_arm", "left_thigh": "body", "left_calf": "left_thigh",
	"left_foot": "left_calf", "right_thigh": "body", "right_calf": "right_thigh", "right_foot": "right_calf"}
const ENDS := {"body": ["hip", "shoulder"], "head": ["head", "nose"],
	"left_upper_arm": ["shoulder", "left_elbow"], "left_forearm": ["left_elbow", "left_hand"],
	"right_upper_arm": ["shoulder", "right_elbow"], "right_forearm": ["right_elbow", "right_hand"],
	"left_thigh": ["hip", "left_knee"], "left_calf": ["left_knee", "left_ankle"], "left_foot": ["left_ankle", "left_toe"],
	"right_thigh": ["hip", "right_knee"], "right_calf": ["right_knee", "right_ankle"], "right_foot": ["right_ankle", "right_toe"]}
var parts: Dictionary = {}
var joints: Dictionary = {}
var phase := 0.0
var pose_name := "idle"
var facing := 1.0
var layout: Dictionary = {}
var display_bones: Dictionary = {}

func _ready() -> void:
	for part_name in PARTS:
		var part := NinjaPart.new()
		part.name = part_name
		part.head = part_name == "head"
		part.thickness = 1.8 if part_name == "body" else 1.5
		if part_name.begins_with("left_"):
			part.color = Color("484853")
		# Keep all nested bones on the world's layer. Negative relative Z on
		# every left bone accumulated and put limbs behind the scene backdrop.
		part.z_index = 0
		parts[part_name] = part
		var parent_name: String = PARENTS[part_name]
		var parent: Node2D = self if parent_name.is_empty() else parts[parent_name]
		parent.add_child(part)
	set_pose(make_pose("idle", 0, 0, 0, 1), 1.0)

func animate(n: NinjaBody, _delta: float, fraction: float = 1.0) -> void:
	facing = n.facing
	scale.x = facing
	pose_name = n.pose_name()
	phase = n.run_distance / 64.8 * TAU if pose_name == "run" else n.animation_age * 7
	set_pose(n.visual_pose(fraction))

func set_part_texture(part_name: String, texture: Texture2D) -> void:
	if parts.has(part_name):
		parts[part_name].texture = texture
		parts[part_name].texture_region = Rect2(texture.get_image().get_used_rect()) if texture != null else Rect2()
		parts[part_name].queue_redraw()

func set_pose(target: Dictionary, weight: float = 1.0, stance: String = "") -> void:
	if not stance.is_empty(): pose_name = stance
	for key in target:
		joints[key] = target[key] if weight >= 1.0 or not joints.has(key) else (joints[key] as Vector2).lerp(target[key], weight)
	var transforms := {"": Transform2D.IDENTITY}
	display_bones = NinjaRigLayout.arrange(joints, layout, parts, pose_name) if not layout.is_empty() else {}
	for part_name in PARTS:
		var ends: Array = ENDS[part_name]
		var start: Vector2 = joints[ends[0]]
		var end: Vector2 = joints[ends[1]]
		if not display_bones.is_empty():
			start = display_bones[part_name].start
			end = display_bones[part_name].end
		var absolute := Transform2D((end - start).angle(), start)
		var parent_transform: Transform2D = transforms[PARENTS[part_name]]
		var part: NinjaPart = parts[part_name]
		part.transform = parent_transform.affine_inverse() * absolute
		part.length = start.distance_to(end)
		part.image_layout = display_bones[part_name].config if not display_bones.is_empty() else {}
		part.image_scale = layout.get("scale", 1.0)
		part.z_as_relative = false
		part.z_index = int(part.image_layout.get("layer", 0)) if part.texture != null else 0
		transforms[part_name] = absolute
		part.queue_redraw()

func set_ragdoll(rag: NinjaRagdoll, fraction: float) -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	var transforms := {"": Transform2D.IDENTITY}
	var pose := {}
	for key in ENDS:
		var names: Array = ENDS[key]
		for joint in names:
			if joint == "nose": continue
			var point: Dictionary = rag.points[joint]
			pose[joint] = point.previous.lerp(point.pos, fraction)
	pose.nose = pose.head + (pose.shoulder - pose.head).rotated(-PI / 2).normalized()
	# Death poses use their existing mapping, even if death interrupted a run.
	var rag_stance := "ragdoll" if pose_name == "run" else pose_name
	var arranged := NinjaRigLayout.arrange(pose, layout, parts, rag_stance) if not layout.is_empty() else {}
	for part_name in PARTS:
		var ends: Array = rag.bones[part_name]
		var a: Dictionary = rag.points[ends[0]]
		var b: Dictionary = rag.points[ends[1]]
		var start: Vector2 = a.previous.lerp(a.pos, fraction)
		var end: Vector2 = b.previous.lerp(b.pos, fraction)
		if not arranged.is_empty():
			start = arranged[part_name].start
			end = arranged[part_name].end
			# Detached roots follow their independently simulated fragment.
			var root_name: String = part_name
			while PARENTS[root_name] not in ["", "body"]: root_name = PARENTS[root_name]
			if rag.exploded and root_name in ["left_upper_arm", "right_upper_arm", "left_thigh", "right_thigh"]:
				var root_point: Dictionary = rag.points[rag.bones[root_name][0]]
				var displacement: Vector2 = root_point.previous.lerp(root_point.pos, fraction) - pose[ENDS[root_name][0]]
				start += displacement
				end += displacement
		var angle := (end - start).angle()
		if part_name == "head" and arranged.is_empty(): angle -= PI / 2
		var absolute := Transform2D(angle, start)
		var part: NinjaPart = parts[part_name]
		part.transform = (transforms[PARENTS[part_name]] as Transform2D).affine_inverse() * absolute
		part.length = start.distance_to(end)
		if not arranged.is_empty(): part.image_layout = arranged[part_name].config
		transforms[part_name] = absolute
		part.queue_redraw()

static func make_pose(stance: String, cycle: float, speed: float, vertical: float, wall_side: float) -> Dictionary:
	return NinjaAnimation.make_pose(stance, cycle, speed, vertical, wall_side)

static func solve_limb(origin: Vector2, target: Vector2, upper: float, lower: float, bend: float) -> Array[Vector2]:
	return NinjaAnimation.solve_limb(origin, target, upper, lower, bend)

func visual_bounds() -> Rect2:
	var bounds := Rect2()
	var first := true
	var inverse := global_transform.affine_inverse()
	for part in parts.values():
		var local := Rect2(-3, -3, 6, 6) if part.head else Rect2(0, -1, part.length, 2)
		var image_rotation := Transform2D.IDENTITY
		if part.texture != null:
			var config: Dictionary = part.image_layout
			var size := NinjaRigLayout.image_size(config, part.texture_region, part.image_scale)
			var pivot := NinjaRigLayout.anchor(config, "pivot")
			local = Rect2(-pivot * size, size)
			image_rotation = Transform2D(-((NinjaRigLayout.anchor(config, "tip") - pivot) * size).angle(), Vector2.ZERO)
		var transform: Transform2D = inverse * part.global_transform * image_rotation
		for point in [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
			var at: Vector2 = transform * point
			bounds = Rect2(at, Vector2.ZERO) if first else bounds.expand(at)
			first = false
	return bounds
