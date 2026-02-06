extends Node
## GameState — central autoload singleton.
##
## Single source of truth for all player state. Runs the idle tick,
## handles master resets, and provides convenience accessors.
##
## Registered as autoload "GameState" in project.godot.

# ---- Sub-systems ----

class CurrencyBundle:
	var power_level := Currencies.PowerLevelState.new()
	var pedometer := Currencies.PedometerState.new()
	var gold := Currencies.GoldState.new()

	func effective_power_level() -> float:
		return power_level.effective()

var currencies := CurrencyBundle.new()
var variables := Variables.State.new()
var mastery := Combat.MasteryState.new()
var active_combat_theme: int = Combat.CombatTheme.UNARMED
var speed := Speed.State.new()
var managers := Managers.State.new()
var environment := GameEnvironment.ProgressionState.new()
var equipment := Tools.EquipmentState.new()

var total_play_time: float = 0.0

# ---- Signals ----

signal power_level_changed(effective_pl: float)
signal gold_changed(balance: float)
signal variable_trained(kind: int, new_value: float)
signal environment_changed(env_name: String)
signal master_reset_performed(current_pl_lost: float)


# ---- Tick ----

func _process(delta: float) -> void:
	tick(delta)


func tick(elapsed_seconds: float) -> void:
	total_play_time += elapsed_seconds
	_tick_managers(elapsed_seconds)


func _tick_managers(elapsed_seconds: float) -> void:
	var elapsed_hours := elapsed_seconds / 3600.0
	for type_key in Managers.TaskManagerType.values():
		var gains_per_hour := managers.passive_gains_per_hour(type_key)
		if gains_per_hour <= 0:
			continue
		var activity: int = Managers.TASK_MANAGER_ACTIVITY[type_key]
		var variable_kind: int = Variables.ACTIVITY_VARIABLE_MAP[activity]
		var amount := gains_per_hour * elapsed_hours
		variables.train(variable_kind, amount)


# ---- Movement ----

func tick_movement(elapsed_seconds: float) -> float:
	var spd := speed.effective_speed()
	var steps := spd * elapsed_seconds
	currencies.pedometer.add_steps(steps)
	return steps


# ---- Pedometer spend ----

func spend_pedometer_for_upgrade() -> Dictionary:
	var result := currencies.pedometer.spend()
	var speed_applied := 0.0
	var pl_applied := 0.0

	if not speed.is_pedometer_capped():
		speed_applied = result["speed_bonus_percent"]
		speed.apply_pedometer_upgrade(speed_applied)
	else:
		pl_applied = floorf(result["speed_bonus_percent"] / 10.0)
		currencies.power_level.add_permanent(pl_applied)

	return {
		"steps_spent": result["steps_spent"],
		"speed_bonus_applied": speed_applied,
		"power_level_bonus_applied": pl_applied,
	}


# ---- Master reset (rebirth) ----

func perform_master_reset() -> Dictionary:
	var current_pl_lost := currencies.power_level.reset()
	var new_env := environment.advance()
	var new_name: String = ""
	var new_theme: int = -1

	if new_env.size() > 0:
		active_combat_theme = new_env["combat_theme"]
		new_name = new_env["name"]
		new_theme = new_env["combat_theme"]

	master_reset_performed.emit(current_pl_lost)
	if new_name != "":
		environment_changed.emit(new_name)

	return {
		"current_pl_lost": current_pl_lost,
		"new_environment_name": new_name,
		"new_theme": new_theme,
	}


# ---- Combat theme ----

func required_combat_theme() -> int:
	return environment.current_combat_theme()


func get_effective_power_level() -> float:
	return currencies.effective_power_level()
