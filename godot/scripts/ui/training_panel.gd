extends PanelContainer
## Training panel — buttons for each laborious activity.
## Active training: tap an activity to train it manually.

@onready var activity_list: VBoxContainer = %ActivityList
@onready var active_label: Label = %ActiveTrainingLabel

var _active_activity: int = -1
var _training_rate: float = 0.0

const ACTIVITY_NAMES: Dictionary = {
	Variables.TrainingActivity.MINING: "Mining",
	Variables.TrainingActivity.LUMBERJACKING: "Lumberjacking",
	Variables.TrainingActivity.OBSTACLE_COURSE: "Obstacle Course",
	Variables.TrainingActivity.MEDITATION: "Meditation",
	Variables.TrainingActivity.DISTANCE_RUNNING: "Distance Running",
	Variables.TrainingActivity.FISHING: "Fishing",
	Variables.TrainingActivity.FARMING: "Farming",
}

const VARIABLE_NAMES: Dictionary = {
	Variables.Kind.STRENGTH: "STR",
	Variables.Kind.DEXTERITY: "DEX",
	Variables.Kind.FOCUS: "FOC",
	Variables.Kind.ENDURANCE: "END",
	Variables.Kind.LUCK: "LCK",
}


func _ready() -> void:
	_build_activity_buttons()
	_update_display()


func _process(delta: float) -> void:
	# Active training tick
	if _active_activity >= 0:
		var kind: int = Variables.ACTIVITY_VARIABLE_MAP[_active_activity]
		var amount := Variables.TrainingIntensity.CASUAL * delta / 3600.0
		# Apply tool efficiency
		var tool_mult := GameState.equipment.tool_efficiency(_active_activity)
		amount *= tool_mult
		GameState.variables.train(kind, amount)
		_training_rate += amount

	_update_display()


func _build_activity_buttons() -> void:
	for child in activity_list.get_children():
		child.queue_free()

	for activity_key in ACTIVITY_NAMES:
		var btn := Button.new()
		btn.name = "Activity_%d" % activity_key
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(_on_activity_pressed.bind(activity_key))
		activity_list.add_child(btn)


func _on_activity_pressed(activity: int) -> void:
	if _active_activity == activity:
		_active_activity = -1  # Toggle off
	else:
		_active_activity = activity
		_training_rate = 0.0


func _update_display() -> void:
	if active_label == null:
		return

	if _active_activity >= 0:
		active_label.text = "Training: %s" % ACTIVITY_NAMES.get(_active_activity, "???")
	else:
		active_label.text = "Tap an activity to train"

	var idx := 0
	for activity_key in ACTIVITY_NAMES:
		if idx >= activity_list.get_child_count():
			break
		var btn: Button = activity_list.get_child(idx)
		var kind: int = Variables.ACTIVITY_VARIABLE_MAP[activity_key]
		var val: float = GameState.variables.get_value(kind)
		var var_name: String = VARIABLE_NAMES.get(kind, "???")
		var act_name: String = ACTIVITY_NAMES[activity_key]
		btn.text = "%s  [%s: %.0f]" % [act_name, var_name, val]
		btn.button_pressed = (_active_activity == activity_key)
		idx += 1
