extends Control
## Temporary main UI — displays core state for testing.
## Will be replaced with proper UI scenes as development progresses.

@onready var power_label: Label = $VBoxContainer/PowerLevelLabel
@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var env_label: Label = $VBoxContainer/EnvironmentLabel
@onready var steps_label: Label = $VBoxContainer/StepsLabel


func _process(_delta: float) -> void:
	var gs = GameState
	power_label.text = "Power Level: %d (perm: %d)" % [
		gs.currencies.effective_power_level(),
		gs.currencies.power_level.permanent,
	]
	gold_label.text = "Gold: %d" % gs.currencies.gold.balance
	env_label.text = "Environment: %s" % gs.environment.current_environment_name()
	steps_label.text = "Steps: %d" % gs.currencies.pedometer.steps
