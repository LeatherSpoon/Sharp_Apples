extends Node
## Main scene controller — manages the top banner, bottom nav,
## content switching (overworld / training / combat), and stat display.

# ---- Top Banner ----
@onready var settings_button: Button = %SettingsButton
@onready var power_level_label: Label = %PowerLevelLabel
@onready var menu_button: Button = %MenuButton

# ---- Stats Bar ----
@onready var gold_label: Label = %GoldLabel
@onready var env_label: Label = %EnvironmentLabel
@onready var steps_label: Label = %StepsLabel

# ---- Content Areas ----
@onready var world: Node2D = $World
@onready var combat_view: Control = %CombatView
@onready var training_panel: PanelContainer = %TrainingPanel

# ---- Bottom Nav ----
@onready var overworld_btn: Button = %OverworldBtn
@onready var train_btn: Button = %TrainBtn
@onready var fight_btn: Button = %FightBtn
@onready var gear_btn: Button = %GearBtn

# ---- Popups ----
@onready var settings_popup: PanelContainer = %SettingsPopup
@onready var menu_popup: PanelContainer = %MenuPopup

enum ViewMode { OVERWORLD, TRAINING, COMBAT }
var _current_view: int = ViewMode.OVERWORLD


func _ready() -> void:
	overworld_btn.pressed.connect(_switch_to.bind(ViewMode.OVERWORLD))
	train_btn.pressed.connect(_switch_to.bind(ViewMode.TRAINING))
	fight_btn.pressed.connect(_start_random_encounter)
	gear_btn.pressed.connect(_toggle_gear)
	settings_button.pressed.connect(_toggle_settings)
	menu_button.pressed.connect(_toggle_menu)
	combat_view.combat_finished.connect(_on_combat_finished)
	combat_view.combat_fled.connect(_on_combat_fled)
	_switch_to(ViewMode.OVERWORLD)


func _process(_delta: float) -> void:
	_update_banner()
	_update_stats()


func _update_banner() -> void:
	var eff_pl := GameState.currencies.effective_power_level()
	var perm := GameState.currencies.power_level.permanent
	power_level_label.text = "PL %d" % int(eff_pl)
	if perm > 0:
		power_level_label.text += " (+%d)" % int(perm)


func _update_stats() -> void:
	gold_label.text = "Gold: %d" % int(GameState.currencies.gold.balance)
	env_label.text = GameState.environment.current_environment_name()
	steps_label.text = "Steps: %d" % int(GameState.currencies.pedometer.steps)


# ---- View switching ----

func _switch_to(view: int) -> void:
	_current_view = view
	world.visible = (view == ViewMode.OVERWORLD)
	training_panel.visible = (view == ViewMode.TRAINING)
	combat_view.visible = (view == ViewMode.COMBAT)
	overworld_btn.button_pressed = (view == ViewMode.OVERWORLD)
	train_btn.button_pressed = (view == ViewMode.TRAINING)
	settings_popup.visible = false
	menu_popup.visible = false


# ---- Combat ----

func _start_random_encounter() -> void:
	var env := GameState.environment.current_environment()
	var tier: int = env["tier"]

	var opp := Encounter.OpponentDefinition.new()
	opp.id = "env_%s_mob" % env["id"]
	opp.opponent_name = "%s Guardian" % env["name"]
	opp.base_power = 10.0 * tier
	opp.base_hp = 30.0 + 20.0 * tier
	opp.base_damage = 3.0 + 2.0 * tier
	opp.attack_speed = 1.0
	opp.gold_reward = 10.0 * tier
	opp.pl_reward = 5.0 * tier
	opp.mastery_xp_reward = 3.0 * tier
	opp.environment_id = env["id"]
	opp.is_boss = false

	_switch_to(ViewMode.COMBAT)
	combat_view.start_combat(opp)


func _on_combat_finished(_rewards: Dictionary) -> void:
	_switch_to(ViewMode.OVERWORLD)


func _on_combat_fled() -> void:
	_switch_to(ViewMode.OVERWORLD)


func _toggle_gear() -> void:
	pass  # Future equipment UI


func _toggle_settings() -> void:
	settings_popup.visible = not settings_popup.visible
	menu_popup.visible = false


func _toggle_menu() -> void:
	menu_popup.visible = not menu_popup.visible
	settings_popup.visible = false
