extends Node
## GameState — central autoload singleton.
##
## Single source of truth for all player state. Runs the idle tick,
## handles meditation (rebirth), and provides convenience accessors.
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

# ---- EXP / Level system ----
var player_level: int = 1
var player_exp: float = 0.0
var stat_points: int = 0
var total_victories: int = 0

const BASE_EXP_REQUIRED: float = 50.0
const EXP_SCALING: float = 1.2

# ---- Combat Skills (Attack / Defense) ----
var attack_skill: float = 1.0
var defense_skill: float = 1.0

# ---- Resource Tracking ----
var trees_destroyed: int = 0
var boulders_destroyed: int = 0
const RESOURCE_BONUS_THRESHOLD: int = 1  # testing: 1, release: raise significantly

# ---- Meditation (Rebirth) System ----
var meditation_count: int = 0
var meditation_multiplier: float = 1.0  # multiplier on PL earn rate
var time_since_meditation: float = 0.0  # seconds since last meditation/start

# ---- Step Allocation ----
enum StepAllocation { STEPS, ATTACK, DEFENSE }
var step_allocation: int = StepAllocation.STEPS

# ---- Opponent Selection ----
var default_opponent_tier: int = -1  # -1 = show selection popup each time

# ---- PL Shop Permanents ----
var pl_rate_bonus: float = 0.0     # bonus to PL earn rate from PL shop
var perm_attack_bonus: float = 0.0
var perm_defense_bonus: float = 0.0
var perm_hp_bonus: float = 0.0

# ---- Signals ----

signal power_level_changed(effective_pl: float)
signal gold_changed(balance: float)
signal variable_trained(kind: int, new_value: float)
signal environment_changed(env_name: String)
signal master_reset_performed(current_pl_lost: float)
signal player_leveled_up(new_level: int, stat_points_available: int)
signal resource_destroyed(type: String, total: int)
signal meditation_completed(result: Dictionary)


# ---- EXP helpers ----

func exp_required_for_level(level: int) -> float:
	return BASE_EXP_REQUIRED * pow(EXP_SCALING, level - 1)


func award_exp(amount: float) -> void:
	if amount <= 0:
		return
	player_exp += amount
	var required := exp_required_for_level(player_level)
	while player_exp >= required:
		player_exp -= required
		player_level += 1
		stat_points += 1
		required = exp_required_for_level(player_level)
		player_leveled_up.emit(player_level, stat_points)


func spend_stat_point(kind: int) -> bool:
	if stat_points <= 0:
		return false
	stat_points -= 1
	variables.train(kind, 1.0)
	return true


# ---- Effective Combat Stats ----

func effective_attack() -> float:
	var base := attack_skill + perm_attack_bonus
	var str_val := variables.get_value(Variables.Kind.STRENGTH)
	return (base + str_val * 0.1) * currencies.effective_power_level()


func effective_defense() -> float:
	var base := defense_skill + perm_defense_bonus
	var end_val := variables.get_value(Variables.Kind.ENDURANCE)
	return (base + end_val * 0.1) * currencies.effective_power_level()


func effective_max_hp() -> float:
	var base := Variables.max_hp(variables.get_value(Variables.Kind.ENDURANCE))
	return base + perm_hp_bonus


# ---- Resource Destruction ----

func on_resource_destroyed(type: String) -> void:
	var str_gain := 0.1
	if type == "tree":
		trees_destroyed += 1
		variables.train(Variables.Kind.STRENGTH, str_gain)
		if trees_destroyed % RESOURCE_BONUS_THRESHOLD == 0:
			attack_skill += 0.5
		resource_destroyed.emit("tree", trees_destroyed)
	elif type == "boulder":
		boulders_destroyed += 1
		variables.train(Variables.Kind.STRENGTH, str_gain)
		if boulders_destroyed % RESOURCE_BONUS_THRESHOLD == 0:
			defense_skill += 0.5
		resource_destroyed.emit("boulder", boulders_destroyed)


# ---- Step Allocation ----

func allocate_step() -> void:
	match step_allocation:
		StepAllocation.STEPS:
			currencies.pedometer.add_steps(1.0)
		StepAllocation.ATTACK:
			attack_skill += 0.01
		StepAllocation.DEFENSE:
			defense_skill += 0.01


# ---- Tick ----

func _process(delta: float) -> void:
	tick(delta)


func tick(elapsed_seconds: float) -> void:
	total_play_time += elapsed_seconds
	time_since_meditation += elapsed_seconds
	# Passive PL: base rate * meditation multiplier * PL shop bonus
	var pl_rate := meditation_multiplier * (1.0 + pl_rate_bonus)
	currencies.power_level.earn(elapsed_seconds * pl_rate)
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


# ---- Meditation (Rebirth) ----

func perform_meditation() -> Dictionary:
	var pl_at_meditation := currencies.power_level.current
	# Time factor: exponential curve that punishes short sessions heavily.
	# Under 30 min the reward is near-zero; AT 30 min it hits ~63%;
	# beyond 30 min it keeps growing toward the cap, rewarding patience.
	# Formula: 1 - e^(-t/1800)  →  at 5 min ≈ 15%, 15 min ≈ 39%, 30 min ≈ 63%, 60 min ≈ 86%
	var time_factor := 1.0 - exp(-time_since_meditation / 1800.0)
	# Bonus ramps further: square the factor so short sessions are truly weak
	# 5 min ≈ 2%, 15 min ≈ 15%, 30 min ≈ 40%, 60 min ≈ 74%, 120 min ≈ 98%
	var time_bonus := time_factor * time_factor * 2.0
	# PL bonus: logarithmic based on how high PL got
	var pl_bonus := log(maxf(pl_at_meditation, 1.0)) / log(10.0)
	# Multiplier gain compounds — long patient sessions yield big rewards
	var multiplier_gain := (1.0 + pl_bonus) * time_bonus * 0.15

	meditation_multiplier += multiplier_gain
	meditation_count += 1
	time_since_meditation = 0.0

	# Reset PL to 1
	currencies.power_level.current = 1.0
	currencies.power_level.times_reset += 1

	# Reset environment/bosses but keep skills, gold, variables, mastery
	environment = GameEnvironment.ProgressionState.new()
	total_victories = 0

	var result := {
		"multiplier_gained": multiplier_gain,
		"new_multiplier": meditation_multiplier,
		"meditation_count": meditation_count,
		"pl_at_meditation": pl_at_meditation,
		"time_bonus": time_bonus,
	}
	meditation_completed.emit(result)
	master_reset_performed.emit(pl_at_meditation)
	return result


# Legacy wrapper
func perform_master_reset() -> Dictionary:
	return perform_meditation()


# ---- Movement ----

func tick_movement(_elapsed_seconds: float) -> float:
	return 0.0


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


# ---- Combat theme ----

func required_combat_theme() -> int:
	return environment.current_combat_theme()


func get_effective_power_level() -> float:
	return currencies.effective_power_level()
