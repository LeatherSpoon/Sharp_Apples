extends Control
## Combat view — Pokemon/NGU Idle style framing.
## Real-time combat: player must wait for cooldown to attack (no auto-attack).
## Opponent auto-attacks on a timer.
## Player attack/defense are multiplied by Power Level.
## After combat ends, click/tap anywhere to dismiss.

@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var opponent_hp_bar: ProgressBar = %OpponentHPBar
@onready var opponent_hp_label: Label = %OpponentHPLabel
@onready var opponent_cooldown_label: Label = %OpponentCooldownLabel
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var theme_label: Label = %ThemeLabel
@onready var action_buttons: HBoxContainer = %ActionButtons
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var cooldown_bar: ProgressBar = %CooldownBar
@onready var cooldown_label: Label = %CooldownLabel
@onready var attack_btn: Button = %ActionButtons.get_node("AttackBtn")

var _encounter: Encounter.State = null
var _opponent_def: Encounter.OpponentDefinition = null

# Cooldown system
const PLAYER_COOLDOWN_TIME: float = 2.0
const OPPONENT_COOLDOWN_TIME: float = 2.5
var _player_cooldown: float = 0.0
var _opponent_cooldown: float = 0.0
var _combat_active: bool = false
var _waiting_for_dismiss: bool = false
var _was_victory: bool = false


signal combat_finished(rewards: Dictionary)
signal combat_fled()


func start_combat(opponent: Encounter.OpponentDefinition) -> void:
	_opponent_def = opponent
	var max_hp := GameState.effective_max_hp()

	_encounter = Encounter.State.new(opponent, max_hp, max_hp, GameState.active_combat_theme)
	_encounter.begin_combat()

	_player_cooldown = PLAYER_COOLDOWN_TIME
	_opponent_cooldown = OPPONENT_COOLDOWN_TIME
	_combat_active = true
	_waiting_for_dismiss = false
	_was_victory = false

	_update_display()
	result_panel.visible = false
	action_buttons.visible = true
	visible = true


func _process(delta: float) -> void:
	if not _combat_active or _encounter == null:
		return
	if _encounter.phase != Encounter.Phase.ACTIVE:
		return

	# Player cooldown ticks down
	if _player_cooldown > 0:
		_player_cooldown = maxf(_player_cooldown - delta, 0.0)

	# Opponent auto-attack timer
	_opponent_cooldown -= delta
	if _opponent_cooldown <= 0:
		_opponent_auto_attack()
		_opponent_cooldown = OPPONENT_COOLDOWN_TIME

	_update_cooldown_display()


func _gui_input(event: InputEvent) -> void:
	# Click/tap anywhere to dismiss the result screen
	if _waiting_for_dismiss:
		if (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventScreenTouch and event.pressed):
			_dismiss_result()
			accept_event()


func _update_cooldown_display() -> void:
	if _encounter == null:
		return
	var ratio := 1.0 - (_player_cooldown / PLAYER_COOLDOWN_TIME)
	cooldown_bar.value = ratio
	if _player_cooldown <= 0:
		cooldown_label.text = "Ready!"
		attack_btn.disabled = false
	else:
		cooldown_label.text = "Charging... %.1fs" % _player_cooldown
		attack_btn.disabled = true

	opponent_cooldown_label.text = "Next attack: %.1fs" % maxf(_opponent_cooldown, 0.0)


func _opponent_auto_attack() -> void:
	if _encounter == null or _encounter.phase != Encounter.Phase.ACTIVE:
		return

	# Opponent damage reduced by player's effective defense
	var raw_damage := _opponent_def.base_damage
	var eff_def := GameState.effective_defense()
	# Defense formula: damage * 100/(100+defense)
	var reduction := 100.0 / (100.0 + eff_def)
	var final_damage := maxf(raw_damage * reduction, 1.0)
	_encounter.damage_player(final_damage)

	var phase := _encounter.check_resolution()
	_update_display()

	if phase == Encounter.Phase.DEFEAT:
		_end_combat("DEFEAT!", false)


func _update_display() -> void:
	if _encounter == null:
		return
	opponent_name_label.text = _opponent_def.opponent_name
	opponent_hp_bar.max_value = _opponent_def.base_hp
	opponent_hp_bar.value = _encounter.opponent_hp
	opponent_hp_label.text = "%d / %d" % [_encounter.opponent_hp, _opponent_def.base_hp]
	player_hp_bar.max_value = _encounter.player_max_hp
	player_hp_bar.value = _encounter.player_hp
	player_hp_label.text = "%d / %d" % [_encounter.player_hp, _encounter.player_max_hp]

	var theme_names := { 0: "Unarmed", 1: "Armed", 2: "Ranged", 3: "Energy" }
	theme_label.text = theme_names.get(_encounter.player_theme, "Unknown")


func _on_attack_pressed() -> void:
	if _encounter == null or _encounter.phase != Encounter.Phase.ACTIVE:
		return
	if _player_cooldown > 0:
		return

	# Player damage incorporates effective_attack (attack_skill * PL)
	var gs := GameState
	var theme_def: Dictionary = Combat.THEME_DEFINITIONS[_encounter.player_theme]
	var var_scaling := gs.variables.variable_scaling(theme_def["theme_key"])
	var cross_bonus := Combat.cross_theme_mastery_bonus(gs.mastery, _encounter.player_theme)

	var eff_atk := gs.effective_attack()
	var damage := (theme_def["base_damage"] + eff_atk) * (1.0 + var_scaling) * (1.0 + cross_bonus)

	# Crit check
	var luck := gs.variables.get_value(Variables.Kind.LUCK)
	if randf() < Variables.crit_chance(luck):
		damage *= 2.0

	_encounter.damage_opponent(damage)

	# Start cooldown
	_player_cooldown = PLAYER_COOLDOWN_TIME

	# Check resolution
	var phase := _encounter.check_resolution()
	_update_display()

	if phase == Encounter.Phase.VICTORY:
		_end_combat("VICTORY!", true)


func _on_defend_pressed() -> void:
	if _encounter == null or _encounter.phase != Encounter.Phase.ACTIVE:
		return
	# Reset opponent cooldown (block their next attack)
	_opponent_cooldown = OPPONENT_COOLDOWN_TIME
	# Shorter player cooldown as a reward for defending
	_player_cooldown = PLAYER_COOLDOWN_TIME * 0.5


func _on_flee_pressed() -> void:
	if _encounter == null:
		return
	_combat_active = false
	_encounter.exit_encounter()
	visible = false
	combat_fled.emit()


func _end_combat(text: String, victory: bool) -> void:
	_combat_active = false
	_was_victory = victory
	action_buttons.visible = false
	result_panel.visible = true

	if victory:
		var rewards := _encounter.calculate_rewards()
		GameState.currencies.power_level.earn(rewards["power_level_gain"])
		GameState.currencies.gold.earn(rewards["gold"])
		GameState.mastery.award_xp(_encounter.player_theme, rewards["mastery_xp"])
		GameState.award_exp(rewards["gold"] + rewards["power_level_gain"])

		result_label.text = "VICTORY!\nGold: +%d  PL: +%d  XP: +%d\n\nTap anywhere to continue" % [
			rewards["gold"], rewards["power_level_gain"], rewards["mastery_xp"],
		]
	else:
		result_label.text = "DEFEAT!\n\nTap anywhere to continue"

	# Enable click-to-dismiss (small delay to prevent accidental immediate dismiss)
	await get_tree().create_timer(0.3).timeout
	_waiting_for_dismiss = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _dismiss_result() -> void:
	_waiting_for_dismiss = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if _was_victory:
		combat_finished.emit(_encounter.calculate_rewards())
	else:
		combat_finished.emit({})
