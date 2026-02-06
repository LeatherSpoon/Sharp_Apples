extends Control
## Virtual joystick for mobile/touch input (iOS + Android).
## Emits a direction vector that the player script reads each frame.
## Shows only when a touch is active in the joystick area.

signal joystick_input(direction: Vector2)

@onready var base_ring: ColorRect = $BaseRing
@onready var thumb: ColorRect = $BaseRing/Thumb

const JOYSTICK_RADIUS: float = 60.0
const DEAD_ZONE: float = 0.15

var _active_finger: int = -1
var _center: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO


func _ready() -> void:
	base_ring.visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS


func get_output() -> Vector2:
	return _output


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_finger == -1:
			# Only capture if touch is in the lower-left quadrant of the screen
			var vp_size := get_viewport_rect().size
			if event.position.x < vp_size.x * 0.5 and event.position.y > vp_size.y * 0.4:
				_active_finger = event.index
				_center = event.position
				base_ring.global_position = _center - base_ring.size * 0.5
				base_ring.visible = true
				_update_thumb(event.position)
		elif not event.pressed and event.index == _active_finger:
			_release()

	elif event is InputEventScreenDrag and event.index == _active_finger:
		_update_thumb(event.position)


func _update_thumb(touch_pos: Vector2) -> void:
	var diff := touch_pos - _center
	var dist := diff.length()
	if dist > JOYSTICK_RADIUS:
		diff = diff.normalized() * JOYSTICK_RADIUS

	thumb.position = (base_ring.size * 0.5) + diff - (thumb.size * 0.5)

	var normalized := diff / JOYSTICK_RADIUS
	if normalized.length() < DEAD_ZONE:
		_output = Vector2.ZERO
	else:
		_output = normalized
	joystick_input.emit(_output)


func _release() -> void:
	_active_finger = -1
	_output = Vector2.ZERO
	base_ring.visible = false
	thumb.position = (base_ring.size - thumb.size) * 0.5
	joystick_input.emit(Vector2.ZERO)
