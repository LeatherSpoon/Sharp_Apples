extends CharacterBody2D
## Master NPC — patrols back and forth in front of the dojo.
## Click to interact and receive dialogue/advice.

signal master_interacted

const PATROL_SPEED: float = 30.0
const PATROL_DISTANCE: float = 80.0
const PAUSE_DURATION: float = 2.0

var _start_position: Vector2 = Vector2.ZERO
var _direction: float = 1.0
var _pause_timer: float = 0.0
var _is_paused: bool = false


func _ready() -> void:
	_start_position = global_position
	# Brief initial pause
	_pause_timer = 1.0
	_is_paused = true


func _physics_process(delta: float) -> void:
	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0:
			_is_paused = false
		return

	velocity = Vector2(_direction * PATROL_SPEED, 0)
	move_and_slide()

	# Reverse at patrol boundaries
	if abs(global_position.x - _start_position.x) >= PATROL_DISTANCE:
		_direction *= -1.0
		_is_paused = true
		_pause_timer = PAUSE_DURATION
