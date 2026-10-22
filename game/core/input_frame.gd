class_name NinjaInputFrame
extends RefCounted
## Stable input boundary for a future replay adapter; recording is not implemented.
const SCHEMA_VERSION := 3
const LEFT := 1
const RIGHT := 2
const JUMP := 4
const FACE_LEFT := 8
const FACE_RIGHT := 16
const JUMP_PRESS := 32
static var last_direction := 0
static var pending_jump := false

static func observe(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("n_left"): last_direction = -1
		if event.is_action_pressed("n_right"): last_direction = 1
		if event.is_action_pressed("n_jump"): pending_jump = true

static func sample() -> int:
	var bits := 0
	if Input.is_action_pressed("n_left"):
		bits |= LEFT
	if Input.is_action_pressed("n_right"):
		bits |= RIGHT
	if Input.is_action_pressed("n_jump"):
		bits |= JUMP
	if last_direction != 0:
		bits |= FACE_LEFT if last_direction < 0 else FACE_RIGHT
	if pending_jump:
		bits |= JUMP_PRESS
		pending_jump = false
	return bits
