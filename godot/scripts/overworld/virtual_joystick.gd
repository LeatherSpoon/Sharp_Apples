extends Control
## Virtual joystick for mobile/touch input (iOS + Android).
## Invisible — no visual feedback. Hold-to-move: while finger is held down,
## the player moves in the direction from the initial touch point to the finger.
## Emits a direction vector that the player script reads each frame.

signal joystick_input(direction: Vector2)

const DEAD_ZONE: float = 20.0

var _active_finger: int = -1
var _center: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO


func _ready() -> void:
	# IGNORE so this never blocks button clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_output() -> Vector2:
	return _output


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_finger == -1:
			_active_finger = event.index
			_center = event.position
			_update_direction(event.position)
		elif not event.pressed and event.index == _active_finger:
			_release()

	elif event is InputEventScreenDrag and event.index == _active_finger:
		_update_direction(event.position)


func _update_direction(touch_pos: Vector2) -> void:
	var diff := touch_pos - _center
	if diff.length() < DEAD_ZONE:
		_output = Vector2.ZERO
	else:
		_output = diff.normalized()
	joystick_input.emit(_output)


func _release() -> void:
	_active_finger = -1
	_output = Vector2.ZERO
	joystick_input.emit(Vector2.ZERO)
