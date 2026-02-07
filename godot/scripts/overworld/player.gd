extends CharacterBody2D
## Player character — handles movement via keyboard + touch + virtual joystick,
## generates pedometer steps based on actual distance traveled.
## Camera leads ahead in the direction of travel for portrait mode.
## Steps are routed through GameState.allocate_step() for skill allocation.

const MOVE_SPEED: float = 200.0
const PIXELS_PER_STEP: float = 16.0

# Camera look-ahead
const CAMERA_LEAD_X: float = 120.0
const CAMERA_LEAD_Y: float = 240.0
const CAMERA_RETURN_SPEED: float = 3.0
const CAMERA_LEAD_SPEED: float = 2.5

var _joystick_dir: Vector2 = Vector2.ZERO
var _mouse_held: bool = false
var _mouse_world_pos: Vector2 = Vector2.ZERO
var _click_target: Vector2 = Vector2.ZERO
var _is_click_moving: bool = false
var _prev_position: Vector2 = Vector2.ZERO
var _distance_accumulator: float = 0.0
var _camera_offset_target: Vector2 = Vector2.ZERO

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_prev_position = global_position
	_click_target = global_position


func set_joystick_direction(dir: Vector2) -> void:
	_joystick_dir = dir
	if dir.length() > 0.1:
		_is_click_moving = false


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO

	# Keyboard input (WASD + arrows) — highest priority
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Virtual joystick (mobile hold-to-move)
	if input_dir == Vector2.ZERO and _joystick_dir.length() > 0.1:
		input_dir = _joystick_dir

	# Mouse hold-to-move: walk toward cursor while button held
	if _mouse_held and input_dir == Vector2.ZERO:
		var diff := _mouse_world_pos - global_position
		if diff.length() > 8.0:
			input_dir = diff.normalized()

	# Click-to-move: walk to click target
	if _is_click_moving and input_dir == Vector2.ZERO:
		var diff := _click_target - global_position
		if diff.length() > 6.0:
			input_dir = diff.normalized()
		else:
			_is_click_moving = false

	velocity = input_dir * MOVE_SPEED
	move_and_slide()

	# Camera look-ahead
	_update_camera_lead(input_dir, delta)

	# Pedometer: count actual distance traveled in tiles (16px = 1 step)
	# Steps routed through GameState.allocate_step() which respects
	# the player's chosen allocation (Steps / Attack / Defense).
	var distance_moved := global_position.distance_to(_prev_position)
	_prev_position = global_position
	if distance_moved > 0.1:
		_distance_accumulator += distance_moved
		while _distance_accumulator >= PIXELS_PER_STEP:
			_distance_accumulator -= PIXELS_PER_STEP
			GameState.allocate_step()


func _update_camera_lead(input_dir: Vector2, delta: float) -> void:
	if camera == null:
		return
	if input_dir.length() > 0.1:
		_camera_offset_target = Vector2(
			input_dir.x * CAMERA_LEAD_X,
			input_dir.y * CAMERA_LEAD_Y,
		)
		camera.position = camera.position.lerp(_camera_offset_target, CAMERA_LEAD_SPEED * delta)
	else:
		camera.position = camera.position.lerp(Vector2.ZERO, CAMERA_RETURN_SPEED * delta)
		if camera.position.length() < 1.0:
			camera.position = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := get_canvas_transform().affine_inverse() * event.position
		if event.pressed:
			_mouse_held = true
			_mouse_world_pos = world_pos
			_click_target = world_pos
			_is_click_moving = true
		else:
			_mouse_held = false
	elif event is InputEventMouseMotion and _mouse_held:
		_mouse_world_pos = get_canvas_transform().affine_inverse() * event.position
