extends CharacterBody2D
## Player character — handles movement via keyboard + touch + virtual joystick,
## generates pedometer steps while moving.

const MOVE_SPEED: float = 200.0

var _touch_target: Vector2 = Vector2.ZERO
var _is_touch_moving: bool = false
var _joystick_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	_touch_target = global_position


func set_joystick_direction(dir: Vector2) -> void:
	_joystick_dir = dir
	if dir.length() > 0.1:
		_is_touch_moving = false


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO

	# Keyboard input (WASD + arrows)
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Virtual joystick (mobile)
	if input_dir == Vector2.ZERO and _joystick_dir.length() > 0.1:
		input_dir = _joystick_dir

	# Touch/tap-to-move (fallback for mobile)
	if _is_touch_moving and input_dir == Vector2.ZERO:
		var diff := _touch_target - global_position
		if diff.length() > 4.0:
			input_dir = diff.normalized()
		else:
			_is_touch_moving = false

	velocity = input_dir * MOVE_SPEED
	move_and_slide()

	# Generate pedometer steps while moving
	if velocity.length() > 1.0:
		GameState.tick_movement(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touch_target = get_canvas_transform().affine_inverse() * event.position
		_is_touch_moving = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_target = get_canvas_transform().affine_inverse() * event.position
		_is_touch_moving = true
