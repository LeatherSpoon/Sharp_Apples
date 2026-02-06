extends Control
## Combat view — Pokemon/NGU Idle style framing.
## Opponent faces viewer (top), player's back visible (bottom).
## Handles encounter flow: Intro → Active → Victory/Defeat → Exiting.

@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var opponent_hp_bar: ProgressBar = %OpponentHPBar
@onready var opponent_hp_label: Label = %OpponentHPLabel
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var theme_label: Label = %ThemeLabel
@onready var action_buttons: HBoxContainer = %ActionButtons
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

var _encounter: Encounter.State = null
var _opponent_def: Encounter.OpponentDefinition = null


signal combat_finished(rewards: Dictionary)
signal combat_fled()


func start_combat(opponent: Encounter.OpponentDefinition) -> void:
	_opponent_def = opponent
	var gs := GameState
	var max_hp := Variables.max_hp(gs.variables.get_value(Variables.Kind.ENDURANCE))

	_encounter = Encounter.State.new(opponent, max_hp, max_hp, gs.active_combat_theme)
	_encounter.begin_combat()

	_update_display()
	result_panel.visible = false
	action_buttons.visible = true
	visible = true


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

	# Player attacks
	var gs := GameState
	var theme_def: Dictionary = Combat.THEME_DEFINITIONS[_encounter.player_theme]
	var var_scaling := gs.variables.variable_scaling(theme_def["theme_key"])
	var cross_bonus := Combat.cross_theme_mastery_bonus(gs.mastery, _encounter.player_theme)
	var damage := Combat.calculate_damage(
		theme_def["base_damage"],
		gs.currencies.effective_power_level(),
		var_scaling,
		cross_bonus,
		1.0,
	)

	# Crit check
	var luck := gs.variables.get_value(Variables.Kind.LUCK)
	if randf() < Variables.crit_chance(luck):
		damage *= 2.0

	_encounter.damage_opponent(damage)

	# Opponent counterattacks
	var opp_damage := _opponent_def.base_damage
	_encounter.damage_player(opp_damage)

	# Check resolution
	var phase := _encounter.check_resolution()
	_update_display()

	if phase == Encounter.Phase.VICTORY:
		_show_result("VICTORY!", true)
	elif phase == Encounter.Phase.DEFEAT:
		_show_result("DEFEAT!", false)


func _on_defend_pressed() -> void:
	if _encounter == null or _encounter.phase != Encounter.Phase.ACTIVE:
		return
	# Defend: take half damage this turn, no attack
	var opp_damage := _opponent_def.base_damage * 0.5
	_encounter.damage_player(opp_damage)

	var phase := _encounter.check_resolution()
	_update_display()

	if phase == Encounter.Phase.DEFEAT:
		_show_result("DEFEAT!", false)


func _on_flee_pressed() -> void:
	if _encounter == null:
		return
	_encounter.exit_encounter()
	visible = false
	combat_fled.emit()


func _show_result(text: String, victory: bool) -> void:
	action_buttons.visible = false
	result_label.text = text
	result_panel.visible = true

	if victory:
		var rewards := _encounter.calculate_rewards()
		# Apply rewards through GameState
		GameState.currencies.power_level.earn(rewards["power_level_gain"])
		GameState.currencies.gold.earn(rewards["gold"])
		GameState.mastery.award_xp(_encounter.player_theme, rewards["mastery_xp"])

		result_label.text = "VICTORY!\nGold: +%d  PL: +%d  XP: +%d" % [
			rewards["gold"], rewards["power_level_gain"], rewards["mastery_xp"],
		]

	# Auto-close after delay
	await get_tree().create_timer(2.5).timeout
	visible = false
	if victory:
		combat_finished.emit(_encounter.calculate_rewards())
	else:
		combat_finished.emit({})
