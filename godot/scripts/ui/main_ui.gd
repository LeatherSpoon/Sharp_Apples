extends Node
## Main scene controller — manages the top banner, bottom nav,
## content switching (overworld / training / combat / step shop),
## stat display, menu popups, EXP/level bar, stat allocation,
## opponent selection, PL shop, meditation, step skill allocation,
## and virtual joystick.
##
## Gear shop is HIDDEN — player starts bare-fisted. Tools come later.

# ---- Top Banner ----
@onready var settings_button: Button = %SettingsButton
@onready var power_level_value: Label = %PowerLevelValue
@onready var power_level_label: Label = %PowerLevelLabel
@onready var menu_button: Button = %MenuButton

var _displayed_pl: float = 1.0

# ---- Level / EXP Bar ----
@onready var level_label: Label = %LevelLabel
@onready var exp_bar: ProgressBar = %EXPBar
@onready var exp_label: Label = %EXPLabel

# ---- Stats Bar ----
@onready var gold_label: Label = %GoldLabel
@onready var env_label: Label = %EnvironmentLabel
@onready var steps_label: Label = %StepsLabel

# ---- Content Areas ----
@onready var world: Node2D = $World
@onready var combat_view: Control = %CombatView
@onready var training_panel: PanelContainer = %TrainingPanel
@onready var gear_panel: PanelContainer = %GearPanel
@onready var steps_shop_panel: PanelContainer = %StepsShopPanel

# ---- Bottom Nav ----
@onready var overworld_btn: Button = %OverworldBtn
@onready var train_btn: Button = %TrainBtn
@onready var fight_btn: Button = %FightBtn
@onready var gear_btn: Button = %GearBtn

# ---- Popups ----
@onready var settings_popup: PanelContainer = %SettingsPopup
@onready var menu_popup: PanelContainer = %MenuPopup
@onready var stats_popup: PanelContainer = %StatsPopup
@onready var mastery_popup: PanelContainer = %MasteryPopup

# ---- Popup Buttons ----
@onready var settings_close_btn: Button = %CloseBtn
@onready var menu_close_btn: Button = %CloseMenuBtn
@onready var stats_btn: Button = %StatsBtn
@onready var mastery_btn: Button = %MasteryBtn
@onready var managers_btn: Button = %ManagersBtn
@onready var pl_shop_menu_btn: Button = %PLShopBtn
@onready var pedometer_btn: Button = %PedometerBtn
@onready var master_reset_btn: Button = %MasterResetBtn
@onready var close_stats_btn: Button = %CloseStatsBtn
@onready var close_mastery_btn: Button = %CloseMasteryBtn

# ---- Stats Popup ----
@onready var stat_points_label: Label = %StatPointsLabel
@onready var stats_list: VBoxContainer = %StatsList

# ---- Mastery Popup ----
@onready var mastery_list: VBoxContainer = %MasteryList

# ---- Gear ----
@onready var gear_list: VBoxContainer = %GearList

# ---- Steps Shop ----
@onready var steps_balance_label: Label = %StepsBalance
@onready var steps_shop_list: VBoxContainer = %StepsShopList

# ---- Virtual Joystick ----
@onready var virtual_joystick: Control = %VirtualJoystick
@onready var player_node: CharacterBody2D = $World/Player

enum ViewMode { OVERWORLD, TRAINING, COMBAT, GEAR, STEPS_SHOP }
var _current_view: int = ViewMode.OVERWORLD

# ---- Dynamically created UI ----
var _opponent_popup: PanelContainer = null
var _opponent_list: VBoxContainer = null
var _pl_shop_popup: PanelContainer = null
var _pl_shop_list: VBoxContainer = null
var _pl_shop_balance_label: Label = null
var _meditation_popup: PanelContainer = null
var _meditation_info_label: Label = null
var _step_alloc_label: Label = null
var _combat_stats_label: Label = null

# ---- Opponent tiers ----
const OPPONENT_TIERS: Array[Dictionary] = [
	{ "name": "Trainee", "power_mult": 0.5, "hp_mult": 0.5, "damage_mult": 0.3, "reward_mult": 0.3 },
	{ "name": "Guardian", "power_mult": 1.0, "hp_mult": 1.0, "damage_mult": 1.0, "reward_mult": 1.0 },
	{ "name": "Elite", "power_mult": 2.0, "hp_mult": 2.0, "damage_mult": 2.0, "reward_mult": 2.5 },
	{ "name": "Champion", "power_mult": 5.0, "hp_mult": 4.0, "damage_mult": 4.0, "reward_mult": 6.0 },
	{ "name": "Master", "power_mult": 10.0, "hp_mult": 8.0, "damage_mult": 8.0, "reward_mult": 15.0 },
]

# ---- PL Shop items ----
const PL_SHOP_ITEMS: Array[Dictionary] = [
	{ "id": "pl_rate_1", "name": "Ki Flow I", "cost": 50, "desc": "+10% PL gain rate", "type": "pl_rate", "value": 0.1, "repeatable": true },
	{ "id": "pl_rate_2", "name": "Ki Flow II", "cost": 200, "desc": "+25% PL gain rate", "type": "pl_rate", "value": 0.25, "repeatable": true },
	{ "id": "pl_rate_3", "name": "Ki Flow III", "cost": 1000, "desc": "+50% PL gain rate", "type": "pl_rate", "value": 0.5, "repeatable": true },
	{ "id": "atk_perm_1", "name": "Iron Fist I", "cost": 100, "desc": "+1 permanent Attack", "type": "perm_attack", "value": 1.0, "repeatable": true },
	{ "id": "atk_perm_2", "name": "Iron Fist II", "cost": 500, "desc": "+5 permanent Attack", "type": "perm_attack", "value": 5.0, "repeatable": true },
	{ "id": "def_perm_1", "name": "Stone Skin I", "cost": 100, "desc": "+1 permanent Defense", "type": "perm_defense", "value": 1.0, "repeatable": true },
	{ "id": "def_perm_2", "name": "Stone Skin II", "cost": 500, "desc": "+5 permanent Defense", "type": "perm_defense", "value": 5.0, "repeatable": true },
	{ "id": "hp_perm_1", "name": "Vital Force I", "cost": 150, "desc": "+50 max HP", "type": "perm_hp", "value": 50.0, "repeatable": true },
	{ "id": "hp_perm_2", "name": "Vital Force II", "cost": 750, "desc": "+200 max HP", "type": "perm_hp", "value": 200.0, "repeatable": true },
]

var _pl_shop_purchases: Dictionary = {}


func _ready() -> void:
	# Bottom nav
	overworld_btn.pressed.connect(_switch_to.bind(ViewMode.OVERWORLD))
	train_btn.pressed.connect(_switch_to.bind(ViewMode.TRAINING))
	fight_btn.pressed.connect(_on_fight_pressed)
	gear_btn.pressed.connect(_switch_to.bind(ViewMode.GEAR))

	# HIDE Gear button — tools are locked, player starts bare-fisted
	gear_btn.visible = false

	# Top bar
	settings_button.pressed.connect(_toggle_settings)
	menu_button.pressed.connect(_toggle_menu)

	# Close buttons
	settings_close_btn.pressed.connect(_close_settings)
	menu_close_btn.pressed.connect(_close_menu)
	close_stats_btn.pressed.connect(_close_stats)
	close_mastery_btn.pressed.connect(_close_mastery)

	# Menu options
	stats_btn.pressed.connect(_open_stats)
	mastery_btn.pressed.connect(_open_mastery)
	managers_btn.pressed.connect(_on_managers_pressed)
	pl_shop_menu_btn.pressed.connect(_open_pl_shop)
	pedometer_btn.pressed.connect(_open_steps_shop)
	master_reset_btn.text = "Meditate (Rebirth)"
	master_reset_btn.pressed.connect(_open_meditation)

	# Combat
	combat_view.combat_finished.connect(_on_combat_finished)
	combat_view.combat_fled.connect(_on_combat_fled)

	# Virtual joystick
	virtual_joystick.joystick_input.connect(_on_joystick_input)

	_switch_to(ViewMode.OVERWORLD)
	_build_gear_shop()
	_build_stats_list()
	_build_mastery_list()
	_build_steps_shop()

	# Create dynamic popups
	_create_opponent_popup()
	_create_pl_shop_popup()
	_create_meditation_popup()


func _process(_delta: float) -> void:
	_update_banner()
	_update_stats()
	_update_exp_bar()
	if _current_view == ViewMode.STEPS_SHOP:
		_refresh_steps_shop()


func _update_banner() -> void:
	var eff_pl := GameState.currencies.effective_power_level()
	var perm := GameState.currencies.power_level.permanent

	if abs(_displayed_pl - eff_pl) > 0.5:
		_displayed_pl = lerpf(_displayed_pl, eff_pl, 0.15)
	else:
		_displayed_pl = eff_pl

	power_level_value.text = "%d" % int(_displayed_pl)

	var extra := ""
	if perm > 0:
		extra += " +%d perm" % int(perm)
	if GameState.meditation_count > 0:
		extra += " x%.1f" % GameState.meditation_multiplier
	if extra != "":
		power_level_label.text = "POWER LEVEL (%s)" % extra.strip_edges()
	else:
		power_level_label.text = "POWER LEVEL"


func _update_stats() -> void:
	gold_label.text = "Gold: %d" % int(GameState.currencies.gold.balance)
	env_label.text = GameState.environment.current_environment_name()
	match GameState.step_allocation:
		GameState.StepAllocation.STEPS:
			steps_label.text = "Steps: %d" % int(GameState.currencies.pedometer.steps)
		GameState.StepAllocation.ATTACK:
			steps_label.text = "ATK: %.1f" % GameState.attack_skill
		GameState.StepAllocation.DEFENSE:
			steps_label.text = "DEF: %.1f" % GameState.defense_skill


func _update_exp_bar() -> void:
	var required := GameState.exp_required_for_level(GameState.player_level)
	level_label.text = "Lv.%d" % GameState.player_level
	exp_bar.max_value = required
	exp_bar.value = GameState.player_exp
	exp_label.text = "%d / %d EXP" % [int(GameState.player_exp), int(required)]


# ---- View switching ----

func _switch_to(view: int) -> void:
	_current_view = view
	world.visible = (view == ViewMode.OVERWORLD)
	training_panel.visible = (view == ViewMode.TRAINING)
	combat_view.visible = (view == ViewMode.COMBAT)
	gear_panel.visible = (view == ViewMode.GEAR)
	steps_shop_panel.visible = (view == ViewMode.STEPS_SHOP)
	virtual_joystick.visible = (view == ViewMode.OVERWORLD)
	overworld_btn.button_pressed = (view == ViewMode.OVERWORLD)
	train_btn.button_pressed = (view == ViewMode.TRAINING)
	_close_all_popups()


# ---- Virtual Joystick ----

func _on_joystick_input(direction: Vector2) -> void:
	if player_node:
		player_node.set_joystick_direction(direction)


# ===========================================================================
#  OPPONENT SELECTION
# ===========================================================================

func _on_fight_pressed() -> void:
	if GameState.default_opponent_tier >= 0 and GameState.default_opponent_tier < OPPONENT_TIERS.size():
		_start_encounter(GameState.default_opponent_tier)
		return
	_show_opponent_popup()


func _create_opponent_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_opponent_popup = PanelContainer.new()
	_opponent_popup.name = "OpponentPopup"
	_opponent_popup.visible = false
	_opponent_popup.layout_mode = 1
	_opponent_popup.anchors_preset = Control.PRESET_FULL_RECT
	_opponent_popup.anchor_left = 0.05
	_opponent_popup.anchor_top = 0.06
	_opponent_popup.anchor_right = 0.95
	_opponent_popup.anchor_bottom = 0.88
	_opponent_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_opponent_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 8)
	_opponent_popup.add_child(vbox)

	var title := Label.new()
	title.text = "SELECT OPPONENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_combat_stats_label = Label.new()
	_combat_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_stats_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_combat_stats_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_opponent_list = VBoxContainer.new()
	_opponent_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_opponent_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_opponent_list)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Default"
	clear_btn.pressed.connect(func(): GameState.default_opponent_tier = -1; _refresh_opponent_list())
	vbox.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(func(): _opponent_popup.visible = false)
	vbox.add_child(close_btn)


func _show_opponent_popup() -> void:
	_close_all_popups()
	_refresh_opponent_list()
	_opponent_popup.visible = true


func _refresh_opponent_list() -> void:
	for child in _opponent_list.get_children():
		child.queue_free()

	var env := GameState.environment.current_environment()
	var tier: int = env["tier"]
	var eff_atk := GameState.effective_attack()
	var eff_def := GameState.effective_defense()

	_combat_stats_label.text = "Your ATK: %.0f  |  DEF: %.0f  |  HP: %.0f" % [
		eff_atk, eff_def, GameState.effective_max_hp()
	]

	for i in OPPONENT_TIERS.size():
		var opp_data: Dictionary = OPPONENT_TIERS[i]
		var opp_hp: float = (30.0 + 20.0 * tier) * float(opp_data["hp_mult"])
		var opp_dmg: float = (3.0 + 2.0 * tier) * float(opp_data["damage_mult"])
		var opp_reward_gold: float = 10.0 * tier * float(opp_data["reward_mult"])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 11)
		var default_marker := " [DEFAULT]" if GameState.default_opponent_tier == i else ""
		info.text = "%s%s\nHP: %.0f  DMG: %.0f  Gold: %.0f" % [
			opp_data["name"], default_marker, opp_hp, opp_dmg, opp_reward_gold
		]
		row.add_child(info)

		var fight_b := Button.new()
		fight_b.text = "Fight"
		fight_b.custom_minimum_size = Vector2(56, 0)
		fight_b.pressed.connect(_start_encounter.bind(i))
		row.add_child(fight_b)

		var default_b := Button.new()
		default_b.text = "Set Def."
		default_b.custom_minimum_size = Vector2(64, 0)
		default_b.pressed.connect(_set_default_opponent.bind(i))
		row.add_child(default_b)

		_opponent_list.add_child(row)


func _set_default_opponent(tier_idx: int) -> void:
	GameState.default_opponent_tier = tier_idx
	_refresh_opponent_list()


func _start_encounter(tier_idx: int) -> void:
	_opponent_popup.visible = false
	var env := GameState.environment.current_environment()
	var env_tier: int = env["tier"]
	var opp_data: Dictionary = OPPONENT_TIERS[tier_idx]

	var opp := Encounter.OpponentDefinition.new()
	opp.id = "env_%s_%s" % [env["id"], opp_data["name"].to_lower()]
	opp.opponent_name = "%s %s" % [env["name"], opp_data["name"]]
	opp.base_power = 10.0 * env_tier * float(opp_data["power_mult"])
	opp.base_hp = (30.0 + 20.0 * env_tier) * float(opp_data["hp_mult"])
	opp.base_damage = (3.0 + 2.0 * env_tier) * float(opp_data["damage_mult"])
	opp.attack_speed = 1.0
	opp.gold_reward = 10.0 * env_tier * float(opp_data["reward_mult"])
	opp.pl_reward = 5.0 * env_tier * float(opp_data["reward_mult"])
	opp.mastery_xp_reward = 3.0 * env_tier * float(opp_data["reward_mult"])
	opp.environment_id = env["id"]
	opp.is_boss = (tier_idx >= 4)

	_switch_to(ViewMode.COMBAT)
	combat_view.start_combat(opp)


# ===========================================================================
#  PL SHOP
# ===========================================================================

func _create_pl_shop_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_pl_shop_popup = PanelContainer.new()
	_pl_shop_popup.name = "PLShopPopup"
	_pl_shop_popup.visible = false
	_pl_shop_popup.layout_mode = 1
	_pl_shop_popup.anchors_preset = Control.PRESET_FULL_RECT
	_pl_shop_popup.anchor_left = 0.05
	_pl_shop_popup.anchor_top = 0.06
	_pl_shop_popup.anchor_right = 0.95
	_pl_shop_popup.anchor_bottom = 0.88
	_pl_shop_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_pl_shop_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 6)
	_pl_shop_popup.add_child(vbox)

	var title := Label.new()
	title.text = "POWER LEVEL SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Spend current Power Level on permanent upgrades.\nThese persist through Meditation."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 11)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_pl_shop_balance_label = Label.new()
	_pl_shop_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_pl_shop_balance_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_pl_shop_list = VBoxContainer.new()
	_pl_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pl_shop_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_pl_shop_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _pl_shop_popup.visible = false)
	vbox.add_child(close_btn)


func _open_pl_shop() -> void:
	menu_popup.visible = false
	_refresh_pl_shop()
	_pl_shop_popup.visible = true


func _refresh_pl_shop() -> void:
	for child in _pl_shop_list.get_children():
		child.queue_free()

	var current_pl := GameState.currencies.power_level.current
	_pl_shop_balance_label.text = "Current PL: %d" % int(current_pl)

	for item in PL_SHOP_ITEMS:
		var bought: int = _pl_shop_purchases.get(item["id"], 0)
		var cost: float = item["cost"] * pow(1.5, bought)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.text = "%s — %s (%.0f PL)" % [item["name"], item["desc"], cost]
		if bought > 0:
			lbl.text += " [x%d]" % bought
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(56, 0)
		btn.disabled = (current_pl < cost)
		btn.pressed.connect(_on_buy_pl_item.bind(item, cost))
		row.add_child(btn)

		_pl_shop_list.add_child(row)


func _on_buy_pl_item(item: Dictionary, cost: float) -> void:
	if not GameState.currencies.power_level.spend(cost):
		return

	match item["type"]:
		"pl_rate":
			GameState.pl_rate_bonus += item["value"]
		"perm_attack":
			GameState.perm_attack_bonus += item["value"]
		"perm_defense":
			GameState.perm_defense_bonus += item["value"]
		"perm_hp":
			GameState.perm_hp_bonus += item["value"]

	var bought: int = _pl_shop_purchases.get(item["id"], 0)
	_pl_shop_purchases[item["id"]] = bought + 1
	_refresh_pl_shop()


# ===========================================================================
#  MEDITATION
# ===========================================================================

func _create_meditation_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_meditation_popup = PanelContainer.new()
	_meditation_popup.name = "MeditationPopup"
	_meditation_popup.visible = false
	_meditation_popup.layout_mode = 1
	_meditation_popup.anchors_preset = Control.PRESET_FULL_RECT
	_meditation_popup.anchor_left = 0.1
	_meditation_popup.anchor_top = 0.1
	_meditation_popup.anchor_right = 0.9
	_meditation_popup.anchor_bottom = 0.7
	_meditation_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_meditation_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 10)
	_meditation_popup.add_child(vbox)

	var title := Label.new()
	title.text = "MEDITATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_meditation_info_label = Label.new()
	_meditation_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meditation_info_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_meditation_info_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var meditate_btn := Button.new()
	meditate_btn.text = "Meditate Now"
	meditate_btn.custom_minimum_size = Vector2(0, 44)
	meditate_btn.pressed.connect(_do_meditation)
	vbox.add_child(meditate_btn)

	var close_btn := Button.new()
	close_btn.text = "Not Yet"
	close_btn.pressed.connect(func(): _meditation_popup.visible = false)
	vbox.add_child(close_btn)


func _open_meditation() -> void:
	menu_popup.visible = false
	_refresh_meditation_info()
	_meditation_popup.visible = true


func _refresh_meditation_info() -> void:
	var pl := GameState.currencies.power_level.current
	var time_sec := GameState.time_since_meditation
	var time_min := time_sec / 60.0
	# Mirror the formula from GameState.perform_meditation()
	var time_factor := 1.0 - exp(-time_sec / 1800.0)
	var time_bonus := time_factor * time_factor * 2.0
	var pl_bonus := log(maxf(pl, 1.0)) / log(10.0)
	var multiplier_gain := (1.0 + pl_bonus) * time_bonus * 0.15
	var time_pct := time_factor * time_factor * 100.0

	var text := ""
	text += "Meditation resets your Power Level to 1 but makes it grow FASTER.\n"
	text += "Longer sessions = MUCH bigger rewards.\n\n"
	text += "Current PL: %d\n" % int(pl)
	text += "Session time: %.0f min\n" % time_min
	text += "Time strength: %.0f%%\n" % time_pct
	text += "Current multiplier: x%.2f\n" % GameState.meditation_multiplier
	text += "Multiplier gain now: +%.3f\n" % multiplier_gain
	text += "Total meditations: %d\n\n" % GameState.meditation_count
	if time_min < 10:
		text += "Too early! Rewards are almost nothing. Keep training.\n"
	elif time_min < 30:
		text += "Rewards are growing... 30+ min for a strong bonus.\n"
	elif time_min < 60:
		text += "Good session! Reward is solid.\n"
	else:
		text += "Excellent patience! Near-maximum time bonus.\n"
	text += "\nKEPT: Attack, Defense, Skills, Steps, Gold, Mastery\n"
	text += "RESET: Power Level, Bosses, Environment"

	_meditation_info_label.text = text


func _do_meditation() -> void:
	var result := GameState.perform_meditation()
	_meditation_popup.visible = false


# ===========================================================================
#  COMBAT (random encounter replaced with opponent selection)
# ===========================================================================

func _on_combat_finished(_rewards: Dictionary) -> void:
	GameState.total_victories += 1
	_switch_to(ViewMode.OVERWORLD)


func _on_combat_fled() -> void:
	_switch_to(ViewMode.OVERWORLD)


# ---- Popup helpers ----

func _close_all_popups() -> void:
	settings_popup.visible = false
	menu_popup.visible = false
	stats_popup.visible = false
	mastery_popup.visible = false
	if _opponent_popup:
		_opponent_popup.visible = false
	if _pl_shop_popup:
		_pl_shop_popup.visible = false
	if _meditation_popup:
		_meditation_popup.visible = false


func _toggle_settings() -> void:
	_close_all_popups()
	settings_popup.visible = true


func _close_settings() -> void:
	settings_popup.visible = false


func _toggle_menu() -> void:
	_close_all_popups()
	menu_popup.visible = true


func _close_menu() -> void:
	menu_popup.visible = false


# ---- Stats Popup ----

func _open_stats() -> void:
	menu_popup.visible = false
	_refresh_stats_list()
	stats_popup.visible = true


func _close_stats() -> void:
	stats_popup.visible = false


func _build_stats_list() -> void:
	for child in stats_list.get_children():
		child.queue_free()

	var stat_names := {
		Variables.Kind.STRENGTH: "Strength",
		Variables.Kind.DEXTERITY: "Dexterity",
		Variables.Kind.FOCUS: "Focus",
		Variables.Kind.ENDURANCE: "Endurance",
		Variables.Kind.LUCK: "Luck",
	}

	for kind in stat_names:
		var row := HBoxContainer.new()
		row.name = "StatRow_%d" % kind

		var lbl := Label.new()
		lbl.name = "Label"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s: %.0f" % [stat_names[kind], GameState.variables.get_value(kind)]
		row.add_child(lbl)

		var btn := Button.new()
		btn.name = "AddBtn"
		btn.text = "+1"
		btn.custom_minimum_size = Vector2(56, 0)
		btn.pressed.connect(_on_stat_point_spent.bind(kind))
		row.add_child(btn)

		stats_list.add_child(row)

	# Attack/Defense display rows
	var atk_row := HBoxContainer.new()
	atk_row.name = "StatRow_ATK"
	var atk_lbl := Label.new()
	atk_lbl.name = "Label"
	atk_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atk_lbl.text = "Attack: %.1f (eff: %.0f)" % [GameState.attack_skill, GameState.effective_attack()]
	atk_row.add_child(atk_lbl)
	stats_list.add_child(atk_row)

	var def_row := HBoxContainer.new()
	def_row.name = "StatRow_DEF"
	var def_lbl := Label.new()
	def_lbl.name = "Label"
	def_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_lbl.text = "Defense: %.1f (eff: %.0f)" % [GameState.defense_skill, GameState.effective_defense()]
	def_row.add_child(def_lbl)
	stats_list.add_child(def_row)


func _refresh_stats_list() -> void:
	stat_points_label.text = "Stat Points: %d" % GameState.stat_points

	var stat_names := {
		Variables.Kind.STRENGTH: "Strength",
		Variables.Kind.DEXTERITY: "Dexterity",
		Variables.Kind.FOCUS: "Focus",
		Variables.Kind.ENDURANCE: "Endurance",
		Variables.Kind.LUCK: "Luck",
	}

	var idx := 0
	for kind in stat_names:
		if idx >= stats_list.get_child_count():
			break
		var row: HBoxContainer = stats_list.get_child(idx)
		var lbl: Label = row.get_node("Label")
		var btn: Button = row.get_node_or_null("AddBtn")
		lbl.text = "%s: %.0f" % [stat_names[kind], GameState.variables.get_value(kind)]
		if btn:
			btn.disabled = (GameState.stat_points <= 0)
		idx += 1

	var atk_row := stats_list.get_node_or_null("StatRow_ATK")
	if atk_row:
		var lbl: Label = atk_row.get_node("Label")
		lbl.text = "Attack: %.1f (eff: %.0f)" % [GameState.attack_skill, GameState.effective_attack()]
	var def_row := stats_list.get_node_or_null("StatRow_DEF")
	if def_row:
		var lbl: Label = def_row.get_node("Label")
		lbl.text = "Defense: %.1f (eff: %.0f)" % [GameState.defense_skill, GameState.effective_defense()]


func _on_stat_point_spent(kind: int) -> void:
	GameState.spend_stat_point(kind)
	_refresh_stats_list()


# ---- Mastery Popup ----

func _open_mastery() -> void:
	menu_popup.visible = false
	_refresh_mastery_list()
	mastery_popup.visible = true


func _close_mastery() -> void:
	mastery_popup.visible = false


func _build_mastery_list() -> void:
	for child in mastery_list.get_children():
		child.queue_free()

	var theme_names := { 0: "Unarmed", 1: "Armed", 2: "Ranged", 3: "Energy" }
	for theme in Combat.THEME_ORDER:
		var lbl := Label.new()
		lbl.name = "Mastery_%d" % theme
		var m: Combat.ThemeMastery = GameState.mastery.themes[theme]
		var req := Combat.mastery_xp_required(m.level)
		lbl.text = "%s  Lv.%d  (%.0f / %.0f XP)" % [theme_names[theme], m.level, m.xp, req]
		mastery_list.add_child(lbl)


func _refresh_mastery_list() -> void:
	var theme_names := { 0: "Unarmed", 1: "Armed", 2: "Ranged", 3: "Energy" }
	var idx := 0
	for theme in Combat.THEME_ORDER:
		if idx >= mastery_list.get_child_count():
			break
		var lbl: Label = mastery_list.get_child(idx)
		var m: Combat.ThemeMastery = GameState.mastery.themes[theme]
		var req := Combat.mastery_xp_required(m.level)
		lbl.text = "%s  Lv.%d  (%.0f / %.0f XP)" % [theme_names[theme], m.level, m.xp, req]
		idx += 1


# ---- Menu button handlers ----

func _on_managers_pressed() -> void:
	menu_popup.visible = false


func _open_steps_shop() -> void:
	menu_popup.visible = false
	_refresh_steps_shop()
	_switch_to(ViewMode.STEPS_SHOP)


# ===========================================================================
#  STEPS SHOP (with step allocation + skill investment)
# ===========================================================================

const STEP_UPGRADES: Array[Dictionary] = [
	{ "id": "speed_1", "name": "Swift Feet I", "cost": 50, "desc": "+10% movement speed", "type": "speed", "value": 10.0 },
	{ "id": "speed_2", "name": "Swift Feet II", "cost": 150, "desc": "+25% movement speed", "type": "speed", "value": 25.0 },
	{ "id": "speed_3", "name": "Swift Feet III", "cost": 400, "desc": "+50% movement speed", "type": "speed", "value": 50.0 },
	{ "id": "pl_1", "name": "Inner Power I", "cost": 100, "desc": "+5 permanent Power Level", "type": "perm_pl", "value": 5.0 },
	{ "id": "pl_2", "name": "Inner Power II", "cost": 300, "desc": "+15 permanent Power Level", "type": "perm_pl", "value": 15.0 },
	{ "id": "pl_3", "name": "Inner Power III", "cost": 750, "desc": "+50 permanent Power Level", "type": "perm_pl", "value": 50.0 },
	{ "id": "gold_1", "name": "Found Coins I", "cost": 25, "desc": "+50 Gold", "type": "gold", "value": 50.0 },
	{ "id": "gold_2", "name": "Found Coins II", "cost": 75, "desc": "+200 Gold", "type": "gold", "value": 200.0 },
	{ "id": "gold_3", "name": "Found Coins III", "cost": 200, "desc": "+500 Gold", "type": "gold", "value": 500.0 },
	{ "id": "exp_1", "name": "Trail Wisdom I", "cost": 50, "desc": "+30 EXP", "type": "exp", "value": 30.0 },
	{ "id": "exp_2", "name": "Trail Wisdom II", "cost": 150, "desc": "+100 EXP", "type": "exp", "value": 100.0 },
]

var _purchased_step_upgrades: Dictionary = {}


func _build_steps_shop() -> void:
	for child in steps_shop_list.get_children():
		child.queue_free()

	# Step Allocation section
	var alloc_title := Label.new()
	alloc_title.text = "STEP ALLOCATION"
	alloc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alloc_title.add_theme_font_size_override("font_size", 14)
	steps_shop_list.add_child(alloc_title)

	var alloc_desc := Label.new()
	alloc_desc.text = "Choose where your walking steps go:"
	alloc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alloc_desc.add_theme_font_size_override("font_size", 10)
	steps_shop_list.add_child(alloc_desc)

	var alloc_row := HBoxContainer.new()
	alloc_row.name = "AllocRow"
	alloc_row.add_theme_constant_override("separation", 4)

	var btn_steps := Button.new()
	btn_steps.name = "AllocSteps"
	btn_steps.text = "Steps Pool"
	btn_steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_steps.toggle_mode = true
	btn_steps.button_pressed = (GameState.step_allocation == GameState.StepAllocation.STEPS)
	btn_steps.pressed.connect(func(): GameState.step_allocation = GameState.StepAllocation.STEPS; _refresh_alloc_buttons())
	alloc_row.add_child(btn_steps)

	var btn_atk := Button.new()
	btn_atk.name = "AllocAttack"
	btn_atk.text = "Attack"
	btn_atk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_atk.toggle_mode = true
	btn_atk.button_pressed = (GameState.step_allocation == GameState.StepAllocation.ATTACK)
	btn_atk.pressed.connect(func(): GameState.step_allocation = GameState.StepAllocation.ATTACK; _refresh_alloc_buttons())
	alloc_row.add_child(btn_atk)

	var btn_def := Button.new()
	btn_def.name = "AllocDefense"
	btn_def.text = "Defense"
	btn_def.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_def.toggle_mode = true
	btn_def.button_pressed = (GameState.step_allocation == GameState.StepAllocation.DEFENSE)
	btn_def.pressed.connect(func(): GameState.step_allocation = GameState.StepAllocation.DEFENSE; _refresh_alloc_buttons())
	alloc_row.add_child(btn_def)

	steps_shop_list.add_child(alloc_row)

	_step_alloc_label = Label.new()
	_step_alloc_label.name = "AllocInfo"
	_step_alloc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_alloc_label.add_theme_font_size_override("font_size", 10)
	steps_shop_list.add_child(_step_alloc_label)

	var sep := HSeparator.new()
	steps_shop_list.add_child(sep)

	var shop_title := Label.new()
	shop_title.text = "STEP SHOP"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.add_theme_font_size_override("font_size", 14)
	steps_shop_list.add_child(shop_title)

	# PL Shop shortcut
	var pl_shop_btn := Button.new()
	pl_shop_btn.text = "Open Power Level Shop"
	pl_shop_btn.pressed.connect(_open_pl_shop)
	steps_shop_list.add_child(pl_shop_btn)

	var sep2 := HSeparator.new()
	steps_shop_list.add_child(sep2)

	for item in STEP_UPGRADES:
		var row := HBoxContainer.new()
		row.name = "Step_%s" % item["id"]

		var lbl := Label.new()
		lbl.name = "Label"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s — %s (%d steps)" % [item["name"], item["desc"], item["cost"]]
		row.add_child(lbl)

		var btn := Button.new()
		btn.name = "BuyBtn"
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(56, 0)
		btn.pressed.connect(_on_buy_step_upgrade.bind(item))
		row.add_child(btn)

		steps_shop_list.add_child(row)


func _refresh_alloc_buttons() -> void:
	var alloc_row := steps_shop_list.get_node_or_null("AllocRow")
	if alloc_row == null:
		return
	var btn_s: Button = alloc_row.get_node("AllocSteps")
	var btn_a: Button = alloc_row.get_node("AllocAttack")
	var btn_d: Button = alloc_row.get_node("AllocDefense")
	btn_s.button_pressed = (GameState.step_allocation == GameState.StepAllocation.STEPS)
	btn_a.button_pressed = (GameState.step_allocation == GameState.StepAllocation.ATTACK)
	btn_d.button_pressed = (GameState.step_allocation == GameState.StepAllocation.DEFENSE)


func _refresh_steps_shop() -> void:
	steps_balance_label.text = "Steps: %d  |  ATK: %.1f  |  DEF: %.1f" % [
		int(GameState.currencies.pedometer.steps),
		GameState.attack_skill,
		GameState.defense_skill,
	]

	if _step_alloc_label:
		match GameState.step_allocation:
			GameState.StepAllocation.STEPS:
				_step_alloc_label.text = "Walking adds to your Step pool (currency)"
			GameState.StepAllocation.ATTACK:
				_step_alloc_label.text = "Walking trains Attack skill (+0.01/step)"
			GameState.StepAllocation.DEFENSE:
				_step_alloc_label.text = "Walking trains Defense skill (+0.01/step)"

	_refresh_alloc_buttons()

	for i in steps_shop_list.get_child_count():
		var child := steps_shop_list.get_child(i)
		if not child.name.begins_with("Step_"):
			continue
		var btn: Button = child.get_node_or_null("BuyBtn")
		if btn == null:
			continue
		var item_id: String = child.name.substr(5)
		var item_data: Dictionary = {}
		for item in STEP_UPGRADES:
			if item["id"] == item_id:
				item_data = item
				break
		if item_data.is_empty():
			continue

		var steps := GameState.currencies.pedometer.steps
		var bought_count: int = _purchased_step_upgrades.get(item_data["id"], 0)

		if item_data["type"] == "speed" and bought_count > 0:
			btn.text = "Owned"
			btn.disabled = true
		elif steps < item_data["cost"]:
			btn.text = "Buy"
			btn.disabled = true
		else:
			btn.text = "Buy"
			btn.disabled = false


func _on_buy_step_upgrade(item: Dictionary) -> void:
	var cost: float = item["cost"]
	if GameState.currencies.pedometer.steps < cost:
		return

	GameState.currencies.pedometer.steps -= cost

	match item["type"]:
		"speed":
			GameState.speed.apply_pedometer_upgrade(item["value"])
		"perm_pl":
			GameState.currencies.power_level.add_permanent(item["value"])
		"gold":
			GameState.currencies.gold.earn(item["value"])
		"exp":
			GameState.award_exp(item["value"])

	var bought: int = _purchased_step_upgrades.get(item["id"], 0)
	_purchased_step_upgrades[item["id"]] = bought + 1
	_refresh_steps_shop()


# ===========================================================================
#  GEAR SHOP (hidden — player starts bare-fisted, tools come later)
# ===========================================================================

const SHOP_TOOLS: Array[Dictionary] = [
	{ "id": "pickaxe_basic", "name": "Basic Pickaxe", "activity": 0, "tier": 1, "mult": 1.5, "cost": 50, "desc": "Mining +50%" },
	{ "id": "axe_basic", "name": "Basic Axe", "activity": 4, "tier": 1, "mult": 1.5, "cost": 50, "desc": "Lumberjacking +50%" },
	{ "id": "shoes_basic", "name": "Running Shoes", "activity": 3, "tier": 1, "mult": 1.5, "cost": 50, "desc": "Distance Running +50%" },
	{ "id": "rod_basic", "name": "Fishing Rod", "activity": 5, "tier": 1, "mult": 1.5, "cost": 75, "desc": "Fishing +50%" },
	{ "id": "mat_basic", "name": "Meditation Mat", "activity": 2, "tier": 1, "mult": 1.5, "cost": 75, "desc": "Meditation +50%" },
	{ "id": "cones_basic", "name": "Obstacle Cones", "activity": 1, "tier": 1, "mult": 1.5, "cost": 75, "desc": "Obstacle Course +50%" },
	{ "id": "hoe_basic", "name": "Garden Hoe", "activity": 6, "tier": 1, "mult": 1.5, "cost": 50, "desc": "Farming +50%" },
	{ "id": "pickaxe_iron", "name": "Iron Pickaxe", "activity": 0, "tier": 2, "mult": 2.0, "cost": 200, "desc": "Mining +100%" },
	{ "id": "axe_iron", "name": "Iron Axe", "activity": 4, "tier": 2, "mult": 2.0, "cost": 200, "desc": "Lumberjacking +100%" },
	{ "id": "shoes_pro", "name": "Pro Sneakers", "activity": 3, "tier": 2, "mult": 2.0, "cost": 200, "desc": "Distance Running +100%" },
]


func _build_gear_shop() -> void:
	for child in gear_list.get_children():
		child.queue_free()

	for item in SHOP_TOOLS:
		var row := HBoxContainer.new()
		row.name = "Gear_%s" % item["id"]

		var lbl := Label.new()
		lbl.name = "Label"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s — %s (%dg)" % [item["name"], item["desc"], item["cost"]]
		row.add_child(lbl)

		var btn := Button.new()
		btn.name = "BuyBtn"
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(56, 0)
		btn.pressed.connect(_on_buy_tool.bind(item))
		row.add_child(btn)

		gear_list.add_child(row)

	_refresh_gear_shop()


func _refresh_gear_shop() -> void:
	var idx := 0
	for item in SHOP_TOOLS:
		if idx >= gear_list.get_child_count():
			break
		var row: HBoxContainer = gear_list.get_child(idx)
		var btn: Button = row.get_node("BuyBtn")
		var activity: int = item["activity"]
		var current_tier := GameState.equipment.get_tool_tier(activity)
		var gold := GameState.currencies.gold.balance

		if current_tier >= item["tier"]:
			btn.text = "Owned"
			btn.disabled = true
		elif gold < item["cost"]:
			btn.text = "Buy"
			btn.disabled = true
		else:
			btn.text = "Buy"
			btn.disabled = false
		idx += 1


func _on_buy_tool(item: Dictionary) -> void:
	var cost: float = item["cost"]
	if not GameState.currencies.gold.spend(cost):
		return

	var tool_def := Tools.ToolDefinition.new()
	tool_def.id = item["id"]
	tool_def.tool_name = item["name"]
	tool_def.activity = item["activity"]
	tool_def.tier = item["tier"]
	tool_def.efficiency_multiplier = item["mult"]
	tool_def.description = item["desc"]
	GameState.equipment.equip_tool(tool_def)
	_refresh_gear_shop()


# ===========================================================================
#  HELPERS
# ===========================================================================

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	style.content_margin_left = 16.0
	style.content_margin_top = 16.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 16.0
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style
