class_name NinjaBody
extends RefCounted
## Seconds-based 120 Hz movement. Default cap is 5% above the original floor guard.
## Input acceleration reaches the chosen target speed; passive drag cannot change it.
const RADIUS := 10.0
const SPEED := 216.0
var max_speed := SPEED
const GROUND_ACCEL := 180.0
const AIR_ACCEL := 120.0
const GRAVITY := 240.0
const JUMP_GRAVITY := 40.0
const MAX_HOLD := 0.75
const WALL_RETAIN := 0.72
const JUMP_BUFFER := 0.12
const WALL_GRACE := 0.10
enum Motion { STANDING, RUNNING, SKIDDING, JUMPING, FALLING, WALLSLIDING, WALLCLIMBING, WALLJUMPING }
var pos := Vector2.ZERO
var previous_pos := Vector2.ZERO
var velocity := Vector2.ZERO
var floor_normal := Vector2.UP
var wall_normal := Vector2.ZERO
var on_floor := false
var near_wall := false
var alive := true
var jumped := false
var jump_age := 0.0
var last_jump := false
var facing := 1.0
var motion := Motion.FALLING
var death_reason := ""
var just_jumped := false
var was_on_floor := false
var incoming_velocity := Vector2.ZERO
var last_directions := 0
var input_axis := 0.0
var wall_jump := false
var jump_wall_normal := Vector2.ZERO
var animation_age := 0.0
var run_distance := 0.0
var previous_run_distance := 0.0
var death_explosive := false
var death_origin := Vector2.ZERO
var death_impulse := Vector2.ZERO
var touched_wall := false
var previous_pose: Dictionary = {}
var jump_buffer := 0.0
var wall_grace := 0.0
var grace_normal := Vector2.ZERO
var spent_wall := Vector2.ZERO

func reset(at: Vector2) -> void:
	pos = at
	previous_pos = at
	velocity = Vector2.ZERO
	on_floor = false
	was_on_floor = false
	near_wall = false
	alive = true
	jumped = false
	last_jump = false
	jump_age = 0.0
	motion = Motion.FALLING
	death_reason = ""
	facing = 1.0
	last_directions = 0
	input_axis = 0
	wall_jump = false
	jump_wall_normal = Vector2.ZERO
	floor_normal = Vector2.UP
	wall_normal = Vector2.ZERO
	animation_age = 0
	run_distance = 0
	previous_run_distance = 0
	death_explosive = false
	death_origin = at
	death_impulse = Vector2.ZERO
	touched_wall = false
	previous_pose = {}
	clear_jump_assist()
	spent_wall = Vector2.ZERO

func clear_jump_assist() -> void:
	jump_buffer = 0
	wall_grace = 0
	grace_normal = Vector2.ZERO

func begin_step(dt: float, bits: int, accel_scale: float) -> void:
	previous_pose = visual_pose()
	previous_run_distance = run_distance
	previous_pos = pos
	animation_age += dt
	jump_age += dt
	touched_wall = near_wall
	just_jumped = false
	var axis := float(int((bits & NinjaInputFrame.RIGHT) != 0) - int((bits & NinjaInputFrame.LEFT) != 0))
	input_axis = axis
	var newly_pressed := (bits & 3) & ~last_directions
	last_directions = bits & 3
	if bits & NinjaInputFrame.FACE_LEFT: facing = -1
	elif bits & NinjaInputFrame.FACE_RIGHT: facing = 1
	elif newly_pressed & NinjaInputFrame.RIGHT: facing = 1
	elif newly_pressed & NinjaInputFrame.LEFT: facing = -1
	var held := (bits & NinjaInputFrame.JUMP) != 0
	var pressed := (held and not last_jump) or (bits & NinjaInputFrame.JUMP_PRESS) != 0
	last_jump = held
	jump_buffer = JUMP_BUFFER if pressed else maxf(0, jump_buffer - dt)
	wall_grace = maxf(0, wall_grace - dt)
	remember_wall()
	was_on_floor = on_floor
	var drag: float = pow(0.99, dt * 40.0)
	var horizontal_limit := maxf(max_speed, absf(velocity.x))
	if axis != 0 and (absf(velocity.x) <= max_speed or velocity.x * axis <= 0):
		velocity.x = move_toward(velocity.x, axis * max_speed, (GROUND_ACCEL if on_floor else AIR_ACCEL) * accel_scale * dt)
	else:
		# Keep authored launch-pad impulses; movement input cannot amplify them.
		velocity.x *= drag
	try_buffered_jump()
	if jumped:
		if not held or jump_age > MAX_HOLD:
			jumped = false
	velocity.y *= drag
	velocity.y += (JUMP_GRAVITY if jumped else GRAVITY) * dt
	if on_floor and not jumped:
		if axis == 0:
			velocity.x *= pow(0.8 if absf(velocity.x) < 4.0 else 0.92, dt * 40.0)
		elif velocity.x * axis < 0:
			velocity.x *= pow(0.92, dt * 40.0)
		if axis * floor_normal.x < 0:
			var uphill := Vector2(-floor_normal.y * signf(floor_normal.x) * -1, -absf(floor_normal.x))
			velocity += uphill * 0.5 * absf(floor_normal.y) * GROUND_ACCEL * accel_scale * dt
			velocity.x = clampf(velocity.x, -horizontal_limit, horizontal_limit)
	incoming_velocity = velocity
	pos += velocity * dt
	on_floor = false
	near_wall = false
	wall_normal = Vector2.ZERO

func remember_wall() -> void:
	if not near_wall:
		spent_wall = Vector2.ZERO
	elif wall_normal != spent_wall:
		grace_normal = wall_normal
		wall_grace = WALL_GRACE

func try_buffered_jump() -> void:
	if jump_buffer <= 0 or not alive or just_jumped: return
	if on_floor:
		wall_jump = false
		var normal := Vector2(0, -0.7) if input_axis * floor_normal.x < 0 else floor_normal
		jump(normal)
	elif wall_grace > 0:
		wall_jump = true
		jump_wall_normal = grace_normal
		spent_wall = grace_normal
		var into_wall := input_axis * grace_normal.x < 0 or motion == Motion.WALLSLIDING
		jump(Vector2(grace_normal.x * (1.0 if into_wall else 1.5), -0.5 if into_wall else -0.7))
	else:
		return
	# One press, one impulse. Holding jump never auto-bounces on each wall.
	clear_jump_assist()

func jump(direction: Vector2) -> void:
	if velocity.x * direction.x < 0:
		velocity.x = 0
	if velocity.y * direction.y < 0:
		velocity.y = 0
	velocity += Vector2(direction.x * 40.0, direction.y * 120.0)
	jumped = true
	just_jumped = true
	jump_age = 0
	on_floor = false
	motion = Motion.JUMPING

func apply_contact(normal: Vector2, depth: float, surface_velocity: Vector2 = Vector2.ZERO) -> void:
	pos += normal * depth
	var relative := velocity - surface_velocity
	if relative.dot(normal) < 0:
		velocity -= normal * relative.dot(normal)
	if normal.y < -0.05:
		on_floor = true
		floor_normal = normal
		if not was_on_floor and incoming_velocity.y > 0 and incoming_velocity.dot(normal) < -(360.0 - 80.0 * absf(normal.y)):
			kill("摔落")
	if absf(normal.x) > 0.99:
		near_wall = true
		wall_normal = Vector2(signf(normal.x), 0)

func finish_step(terrain: NinjaTerrain, dt: float = 1.0 / 120.0) -> void:
	for _iteration in range(6):
		var hit := terrain.contact(pos, RADIUS)
		if hit.is_empty():
			break
		apply_contact(hit.normal, hit.depth + 0.0001)
	if terrain.solid(pos + Vector2(RADIUS + 0.1, 0)):
		near_wall = true
		wall_normal = Vector2.LEFT
	elif terrain.solid(pos - Vector2(RADIUS + 0.1, 0)):
		near_wall = true
		wall_normal = Vector2.RIGHT
	# A resting contact can be separated by depenetration epsilon. Probe the
	# floor so running does not flicker into the airborne pose every other tick.
	if not on_floor and not just_jumped and velocity.y >= 0:
		var support := terrain.contact(pos + Vector2(0, 0.15), RADIUS)
		if not support.is_empty() and support.normal.y < -0.05:
			on_floor = true
			floor_normal = support.normal
	remember_wall()
	# A press just before impact must fire on the contact tick, not wait for
	# another press (or another physics tick). Previous jump hold is irrelevant.
	try_buffered_jump()
	if just_jumped and not last_jump: jumped = false
	if near_wall and not on_floor and not just_jumped and input_axis * wall_normal.x <= 0 and velocity.y >= 0:
		# N's wall friction opposes downward sliding. Carry upward momentum
		# through a new wall contact so a released/re-pressed jump can add to it.
		if not touched_wall:
			velocity.y *= 0.72
		else:
			velocity.y *= pow(WALL_RETAIN, dt * 40.0)
		jumped = false
	if on_floor and not just_jumped:
		jumped = false
		wall_jump = false
		motion = Motion.STANDING if absf(velocity.x) < 4 else (Motion.SKIDDING if input_axis * velocity.x <= 0 else Motion.RUNNING)
	elif near_wall and input_axis * wall_normal.x <= 0 and not just_jumped:
		motion = Motion.WALLCLIMBING if velocity.y < -1 else Motion.WALLSLIDING
	elif wall_jump and jump_age < 0.25:
		motion = Motion.WALLJUMPING
	elif jumped or velocity.y < -1:
		motion = Motion.JUMPING
	else:
		motion = Motion.FALLING
	if motion == Motion.RUNNING:
		run_distance += absf((pos - previous_pos).dot(Vector2(-floor_normal.y, floor_normal.x)))
	if pos.x < 10 or pos.x > 782 or pos.y < 10 or pos.y > 590:
		kill("越界")

func pose_name() -> String:
	match motion:
		Motion.STANDING: return "idle"
		Motion.RUNNING: return "run"
		Motion.SKIDDING: return "skid"
		Motion.WALLCLIMBING: return "wall_climb"
		Motion.WALLSLIDING: return "wall_slide"
		Motion.WALLJUMPING: return "wall_jump"
		Motion.JUMPING: return "takeoff" if jump_age < 0.08 else "rise"
		_: return "fall"

func visual_pose(fraction: float = 1.0) -> Dictionary:
	var stance := pose_name()
	var cycle := lerpf(previous_run_distance, run_distance, fraction) / 64.8 * TAU if stance == "run" else (animation_age - (1 - fraction) / 120.0) * 7
	var side := -jump_wall_normal.x * facing if stance == "wall_jump" else -wall_normal.x * facing
	var result := NinjaAnimation.make_pose(stance, cycle, velocity.x * facing, velocity.y, 1.0 if side == 0 else side)
	if on_floor:
		var angle := Vector2(-floor_normal.y, floor_normal.x).angle() * facing
		for key in result: result[key] = result[key].rotated(angle)
	return result

func kill(reason: String, explosive: bool = false, origin: Vector2 = Vector2.ZERO, impulse: Vector2 = Vector2.ZERO) -> void:
	if not alive: return
	alive = false
	death_reason = reason
	death_explosive = explosive
	death_origin = pos if origin == Vector2.ZERO else origin
	death_impulse = impulse
