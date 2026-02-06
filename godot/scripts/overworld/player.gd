extends CharacterBody2D
## Player character — handles movement via keyboard + touch + virtual joystick,
## generates pedometer steps based on actual distance traveled.

const MOVE_SPEED: float = 200.0
const PIXELS_PER_STEP: float = 16.0

var _joystick_dir: Vector2 = Vector2.ZERO
var _mouse_held: bool = false
var _mouse_world_pos: Vector2 = Vector2.ZERO
var _prev_position: Vector2 = Vector2.ZERO
var _distance_accumulator: float = 0.0


func _ready() -> void:
	_prev_position = global_position


func set_joystick_direction(dir: Vector2) -> void:
	_joystick_dir = dir


func _physics_process(_delta: float) -> void:
	var input_dir := Vector2.ZERO

	# Keyboard input (WASD + arrows)
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Virtual joystick (mobile hold-to-move)
	if input_dir == Vector2.ZERO and _joystick_dir.length() > 0.1:
		input_dir = _joystick_dir

	# Mouse hold-to-move: walk toward cursor while held
	if _mouse_held and input_dir == Vector2.ZERO:
		var diff := _mouse_world_pos - global_position
		if diff.length() > 8.0:
			input_dir = diff.normalized()

	velocity = input_dir * MOVE_SPEED
	move_and_slide()

	# Pedometer: count actual distance traveled in tiles (16px = 1 step)
	var distance_moved := global_position.distance_to(_prev_position)
	_prev_position = global_position
	if distance_moved > 0.1:
		_distance_accumulator += distance_moved
		while _distance_accumulator >= PIXELS_PER_STEP:
			_distance_accumulator -= PIXELS_PER_STEP
			GameState.currencies.pedometer.add_steps(1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse hold-to-move (desktop): hold left button to walk toward cursor
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = event.pressed
		if event.pressed:
			_mouse_world_pos = get_canvas_transform().affine_inverse() * event.position
	elif event is InputEventMouseMotion and _mouse_held:
		_mouse_world_pos = get_canvas_transform().affine_inverse() * event.position
