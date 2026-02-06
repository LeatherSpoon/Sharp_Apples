extends PanelContainer
## Training panel — select an activity to actively train a stat.
## While an activity is selected, the corresponding stat increases over time.
## Equipping tools from the Gear shop multiplies training speed.

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

const ACTIVITY_DESCRIPTIONS: Dictionary = {
	Variables.TrainingActivity.MINING: "Trains STR — Boosts Unarmed & Armed damage",
	Variables.TrainingActivity.LUMBERJACKING: "Trains STR — Boosts Unarmed & Armed damage",
	Variables.TrainingActivity.OBSTACLE_COURSE: "Trains DEX — Boosts Ranged accuracy & crit",
	Variables.TrainingActivity.MEDITATION: "Trains FOC — Boosts Energy pool & regen",
	Variables.TrainingActivity.DISTANCE_RUNNING: "Trains END — Boosts max HP & defense",
	Variables.TrainingActivity.FISHING: "Trains LCK — Boosts crit chance & loot quality",
	Variables.TrainingActivity.FARMING: "Trains END — Boosts max HP & defense",
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
		var vbox := VBoxContainer.new()
		vbox.name = "ActivityBox_%d" % activity_key

		var btn := Button.new()
		btn.name = "Button"
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_activity_pressed.bind(activity_key))
		vbox.add_child(btn)

		var desc := Label.new()
		desc.name = "Desc"
		desc.theme_override_font_sizes = { "font_size": 10 }
		desc.text = ACTIVITY_DESCRIPTIONS.get(activity_key, "")
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 10)
		vbox.add_child(desc)

		activity_list.add_child(vbox)


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
		var kind: int = Variables.ACTIVITY_VARIABLE_MAP[_active_activity]
		var var_name: String = VARIABLE_NAMES.get(kind, "???")
		var val: float = GameState.variables.get_value(kind)
		active_label.text = "Training: %s  (%s: %.1f)" % [
			ACTIVITY_NAMES.get(_active_activity, "???"), var_name, val,
		]
	else:
		active_label.text = "Select an activity to train a stat over time"

	var idx := 0
	for activity_key in ACTIVITY_NAMES:
		if idx >= activity_list.get_child_count():
			break
		var vbox: VBoxContainer = activity_list.get_child(idx)
		var btn: Button = vbox.get_node("Button")
		var kind: int = Variables.ACTIVITY_VARIABLE_MAP[activity_key]
		var val: float = GameState.variables.get_value(kind)
		var var_name: String = VARIABLE_NAMES.get(kind, "???")
		var act_name: String = ACTIVITY_NAMES[activity_key]
		var tool_mult := GameState.equipment.tool_efficiency(activity_key)

		var tool_text := ""
		if tool_mult > 1.0:
			tool_text = "  (x%.1f)" % tool_mult

		btn.text = "%s  [%s: %.0f]%s" % [act_name, var_name, val, tool_text]
		btn.button_pressed = (_active_activity == activity_key)
		idx += 1
