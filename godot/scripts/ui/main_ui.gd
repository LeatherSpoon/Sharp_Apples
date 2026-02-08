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
@onready var travel_menu_btn: Button = %TravelBtn
@onready var gold_shop_menu_btn: Button = %GoldShopBtn
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
var _meditate_confirm_btn: Button = null
var _cutscene_overlay: ColorRect = null
var _cutscene_label: Label = null
var _travel_popup: PanelContainer = null
var _travel_list: VBoxContainer = null
var _gold_shop_popup: PanelContainer = null
var _gold_shop_list: VBoxContainer = null
var _gold_shop_balance_label: Label = null
var _step_alloc_label: Label = null
var _combat_stats_label: Label = null
var _font_scale: float = 1.0
var _font_slider: HSlider = null
var _font_value_label: Label = null
var _augment_popup: PanelContainer = null
var _augment_list: VBoxContainer = null
var _energy_info_label: Label = null
var _energy_input: LineEdit = null

# ---- Opponent tiers ----
const OPPONENT_TIERS: Array[Dictionary] = [
	{ "name": "Scrapper", "power_mult": 0.5, "hp_mult": 0.5, "damage_mult": 0.3, "reward_mult": 0.3 },
	{ "name": "Brawler", "power_mult": 1.5, "hp_mult": 1.5, "damage_mult": 1.0, "reward_mult": 1.0 },
	{ "name": "Enforcer", "power_mult": 4.0, "hp_mult": 4.0, "damage_mult": 3.0, "reward_mult": 2.5 },
	{ "name": "Warden", "power_mult": 10.0, "hp_mult": 10.0, "damage_mult": 8.0, "reward_mult": 6.0 },
	{ "name": "Grandmaster", "power_mult": 25.0, "hp_mult": 25.0, "damage_mult": 20.0, "reward_mult": 15.0 },
]

# Environment-specific silly opponent names (overrides default tier names)
const ENVIRONMENT_OPPONENT_NAMES: Dictionary = {
	"forest_dojo": ["Angry Squirrel", "Grumpy Mailman", "Feral Raccoon", "HOA President", "Neighborhood Dad"],
	"deep_mine": ["Cave Bat", "Tunnel Rat", "Lost Miner", "Rock Golem", "Mine Foreman"],
}

# ---- PL Shop items ----
const PL_SHOP_ITEMS: Array[Dictionary] = [
	{ "id": "pl_rate_1", "name": "Power Flow I", "cost": 50, "desc": "+10% PL gain rate", "type": "pl_rate", "value": 0.1, "repeatable": true },
	{ "id": "pl_rate_2", "name": "Power Flow II", "cost": 200, "desc": "+25% PL gain rate", "type": "pl_rate", "value": 0.25, "repeatable": true },
	{ "id": "pl_rate_3", "name": "Power Flow III", "cost": 1000, "desc": "+50% PL gain rate", "type": "pl_rate", "value": 0.5, "repeatable": true },
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
	travel_menu_btn.pressed.connect(_open_travel)
	gold_shop_menu_btn.pressed.connect(_open_gold_shop)
	pl_shop_menu_btn.pressed.connect(_open_pl_shop)
	pedometer_btn.pressed.connect(_open_steps_shop)
	master_reset_btn.text = "Meditate (Prestige)"
	master_reset_btn.pressed.connect(_open_meditation)

	# Combat
	combat_view.combat_finished.connect(_on_combat_finished)
	combat_view.combat_fled.connect(_on_combat_fled)

	# Virtual joystick
	virtual_joystick.joystick_input.connect(_on_joystick_input)

	# World object interactions
	world.mine_entrance_clicked.connect(_on_mine_entrance)
	world.master_npc_clicked.connect(_on_master_npc_interact)

	_switch_to(ViewMode.OVERWORLD)
	_build_gear_shop()
	_build_stats_list()
	_build_mastery_list()
	_build_steps_shop()

	# Create dynamic popups
	_create_opponent_popup()
	_create_travel_popup()
	_create_gold_shop_popup()
	_create_pl_shop_popup()
	_create_meditation_popup()
	_create_augment_popup()

	# Hide Mastery Progress from menu (still accessible elsewhere)
	mastery_btn.visible = false
	# Hide Managers until player is told how to use them
	managers_btn.visible = false

	# Add Augments button to menu (insert before Travel)
	_add_augment_menu_button()

	# Fix menu popup font sizes to match rest of UI
	_apply_menu_font_sizes()

	# Add font size controls to Settings popup
	_setup_font_settings()


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
	# Always show steps count; skill allocation is shown in the Step Shop
	steps_label.text = "Steps: %d" % int(GameState.currencies.pedometer.steps)


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
	# Always show selection popup so player can change opponent or review stats
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
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	_combat_stats_label = Label.new()
	_combat_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_stats_label.add_theme_font_size_override("font_size", 21)
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
	var env_id: String = env["id"]
	var eff_atk := GameState.effective_attack()
	var eff_def := GameState.effective_defense()

	_combat_stats_label.text = "Your ATK: %.0f  |  DEF: %.0f  |  HP: %.0f" % [
		eff_atk, eff_def, GameState.effective_max_hp()
	]

	# PL-based scaling so opponents stay challenging as player grows
	var pl := maxf(GameState.currencies.effective_power_level(), 1.0)
	var pl_scale := 1.0 + sqrt(pl) / 10.0

	# Environment-specific opponent names
	var env_names: Array = ENVIRONMENT_OPPONENT_NAMES.get(env_id, [])

	for i in OPPONENT_TIERS.size():
		var opp_data: Dictionary = OPPONENT_TIERS[i]
		var opp_hp: float = (30.0 + 20.0 * tier) * float(opp_data["hp_mult"]) * pl_scale
		var opp_dmg: float = (3.0 + 2.0 * tier) * float(opp_data["damage_mult"]) * pl_scale
		var opp_reward_gold: float = 10.0 * tier * float(opp_data["reward_mult"]) * pl_scale

		var display_name: String = opp_data["name"]
		if env_names.size() > i:
			display_name = env_names[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", _fs(21))
		var default_marker := " [DEFAULT]" if GameState.default_opponent_tier == i else ""
		info.text = "%s%s\nHP: %.0f  DMG: %.0f  Gold: %.0f" % [
			display_name, default_marker, opp_hp, opp_dmg, opp_reward_gold
		]
		row.add_child(info)

		var fight_b := Button.new()
		fight_b.text = "Fight"
		fight_b.custom_minimum_size = Vector2(56, 0)
		fight_b.add_theme_font_size_override("font_size", _fs(18))
		fight_b.pressed.connect(_start_encounter.bind(i))
		row.add_child(fight_b)

		var default_b := Button.new()
		default_b.text = "Set Def."
		default_b.custom_minimum_size = Vector2(72, 0)
		default_b.add_theme_font_size_override("font_size", _fs(18))
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
	var env_id: String = env["id"]
	var opp_data: Dictionary = OPPONENT_TIERS[tier_idx]

	# PL-based scaling so opponents stay challenging
	var pl := maxf(GameState.currencies.effective_power_level(), 1.0)
	var pl_scale := 1.0 + sqrt(pl) / 10.0

	# Environment-specific names
	var env_names: Array = ENVIRONMENT_OPPONENT_NAMES.get(env_id, [])
	var display_name: String = opp_data["name"]
	if env_names.size() > tier_idx:
		display_name = env_names[tier_idx]

	var opp := Encounter.OpponentDefinition.new()
	opp.id = "env_%s_%s" % [env_id, display_name.to_lower().replace(" ", "_")]
	opp.opponent_name = "%s %s" % [env["name"], display_name]
	opp.base_power = 10.0 * env_tier * float(opp_data["power_mult"]) * pl_scale
	opp.base_hp = (30.0 + 20.0 * env_tier) * float(opp_data["hp_mult"]) * pl_scale
	opp.base_damage = (3.0 + 2.0 * env_tier) * float(opp_data["damage_mult"]) * pl_scale
	opp.attack_speed = 1.0
	opp.gold_reward = 10.0 * env_tier * float(opp_data["reward_mult"]) * pl_scale
	opp.pl_reward = 5.0 * env_tier * float(opp_data["reward_mult"]) * pl_scale
	opp.mastery_xp_reward = 3.0 * env_tier * float(opp_data["reward_mult"])
	opp.environment_id = env_id
	opp.is_boss = (tier_idx >= 4)

	_switch_to(ViewMode.COMBAT)
	combat_view.start_combat(opp)


# ===========================================================================
#  WORLD TRAVEL
# ===========================================================================

func _create_travel_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_travel_popup = PanelContainer.new()
	_travel_popup.name = "TravelPopup"
	_travel_popup.visible = false
	_travel_popup.layout_mode = 1
	_travel_popup.anchors_preset = Control.PRESET_FULL_RECT
	_travel_popup.anchor_left = 0.05
	_travel_popup.anchor_top = 0.06
	_travel_popup.anchor_right = 0.95
	_travel_popup.anchor_bottom = 0.88
	_travel_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_travel_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 6)
	_travel_popup.add_child(vbox)

	var title := Label.new()
	title.text = "WORLD TRAVEL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Travel to a different world. Each has unique challenges."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 21)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_travel_list = VBoxContainer.new()
	_travel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_travel_list)

	var close_btn := Button.new()
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func(): _travel_popup.visible = false)
	vbox.add_child(close_btn)


func _open_travel() -> void:
	menu_popup.visible = false
	_refresh_travel_list()
	_travel_popup.visible = true


func _refresh_travel_list() -> void:
	for child in _travel_list.get_children():
		child.queue_free()

	var current_idx := GameState.environment.current_index

	for i in GameEnvironment.ENVIRONMENTS.size():
		var env: Dictionary = GameEnvironment.ENVIRONMENTS[i]
		var unlocked := GameState.environment.is_unlocked(i)
		var is_current := (i == current_idx)

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 21)
		if unlocked:
			var marker := " [HERE]" if is_current else ""
			info.text = "%s (Tier %d)%s" % [env["name"], env["tier"], marker]
		else:
			info.text = "??? (Tier %d) — Locked" % env["tier"]
			info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(info)

		var btn := Button.new()
		if is_current:
			btn.text = "Here"
			btn.disabled = true
		elif unlocked:
			btn.text = "Travel"
			btn.pressed.connect(_do_travel.bind(i))
		else:
			btn.text = "Locked"
			btn.disabled = true
		btn.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(btn)

		row.add_child(hbox)

		# Description line
		if unlocked:
			var desc_lbl := Label.new()
			desc_lbl.text = env["description"]
			desc_lbl.add_theme_font_size_override("font_size", 18)
			desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(desc_lbl)

		_travel_list.add_child(row)


func _do_travel(env_index: int) -> void:
	if not GameState.environment.travel_to(env_index):
		return
	_travel_popup.visible = false

	var env := GameState.environment.current_environment()

	# Update the world visuals
	if world:
		world.apply_world(env)

	_switch_to(ViewMode.OVERWORLD)


# ---- Mine Entrance ----

func _on_mine_entrance() -> void:
	# Find the Deep Mine environment index and travel there
	for i in GameEnvironment.ENVIRONMENTS.size():
		if GameEnvironment.ENVIRONMENTS[i]["id"] == "deep_mine":
			_do_travel(i)
			return


# ---- Master NPC Interaction ----

const MASTER_DIALOGUES: Array[String] = [
	"Welcome, young one. Your fists are your first weapon. Punch the trees and boulders to grow stronger.",
	"Energy is precious. Allocate it wisely — you cannot train everything at once.",
	"The mine to the west holds greater challenges. When you are ready, step inside.",
	"True power comes not from strength alone, but from patience. Meditate when the time is right.",
	"I see potential in you. Keep training. The path ahead is long.",
	"Have you tried the augments? Even a pair of Safety Scissors can tip the balance.",
	"Each world you visit will test you differently. Adapt or fall.",
	"Gold is earned through combat. Spend it wisely in the shops.",
]

var _master_dialogue_index: int = 0
var _master_dialogue_popup: PanelContainer = null

func _on_master_npc_interact() -> void:
	_close_all_popups()
	if _master_dialogue_popup == null:
		_create_master_dialogue_popup()

	var text: String = MASTER_DIALOGUES[_master_dialogue_index % MASTER_DIALOGUES.size()]
	_master_dialogue_index += 1

	var lbl: Label = _master_dialogue_popup.get_node("VBox/DialogueLabel")
	lbl.text = "Master says:\n\n\"%s\"" % text
	_master_dialogue_popup.visible = true


func _create_master_dialogue_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_master_dialogue_popup = PanelContainer.new()
	_master_dialogue_popup.name = "MasterDialoguePopup"
	_master_dialogue_popup.visible = false
	_master_dialogue_popup.layout_mode = 1
	_master_dialogue_popup.anchors_preset = Control.PRESET_FULL_RECT
	_master_dialogue_popup.anchor_left = 0.08
	_master_dialogue_popup.anchor_top = 0.25
	_master_dialogue_popup.anchor_right = 0.92
	_master_dialogue_popup.anchor_bottom = 0.65
	_master_dialogue_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_master_dialogue_popup)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 8)
	_master_dialogue_popup.add_child(vbox)

	var title := Label.new()
	title.text = "MASTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _fs(27))
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(title)

	var dialogue_lbl := Label.new()
	dialogue_lbl.name = "DialogueLabel"
	dialogue_lbl.text = ""
	dialogue_lbl.add_theme_font_size_override("font_size", _fs(21))
	dialogue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(dialogue_lbl)

	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.add_theme_font_size_override("font_size", _fs(21))
	close_btn.pressed.connect(func(): _master_dialogue_popup.visible = false)
	vbox.add_child(close_btn)


# ===========================================================================
#  GOLD SHOP
# ===========================================================================

const GOLD_SHOP_ITEMS: Array[Dictionary] = [
	{ "id": "stat_point", "name": "Stat Point", "cost": 25, "desc": "+1 stat point to allocate", "type": "stat_point", "value": 1, "repeatable": true },
	{ "id": "exp_small", "name": "Training Scroll", "cost": 30, "desc": "+50 EXP", "type": "exp", "value": 50.0, "repeatable": true },
	{ "id": "exp_large", "name": "Master Scroll", "cost": 150, "desc": "+300 EXP", "type": "exp", "value": 300.0, "repeatable": true },
	{ "id": "atk_boost", "name": "Fist Wraps", "cost": 50, "desc": "+1 base Attack", "type": "attack", "value": 1.0, "repeatable": true },
	{ "id": "def_boost", "name": "Body Armor", "cost": 50, "desc": "+1 base Defense", "type": "defense", "value": 1.0, "repeatable": true },
	{ "id": "hp_boost", "name": "Health Tonic", "cost": 75, "desc": "+50 max HP", "type": "hp", "value": 50.0, "repeatable": true },
	{ "id": "pl_boost", "name": "Power Elixir", "cost": 100, "desc": "+10 Power Level", "type": "pl", "value": 10.0, "repeatable": true },
	{ "id": "steps_buy", "name": "Trail Map", "cost": 40, "desc": "+25 Steps", "type": "steps", "value": 25.0, "repeatable": true },
]

var _gold_shop_purchases: Dictionary = {}


func _create_gold_shop_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_gold_shop_popup = PanelContainer.new()
	_gold_shop_popup.name = "GoldShopPopup"
	_gold_shop_popup.visible = false
	_gold_shop_popup.layout_mode = 1
	_gold_shop_popup.anchors_preset = Control.PRESET_FULL_RECT
	_gold_shop_popup.anchor_left = 0.05
	_gold_shop_popup.anchor_top = 0.06
	_gold_shop_popup.anchor_right = 0.95
	_gold_shop_popup.anchor_bottom = 0.88
	_gold_shop_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_gold_shop_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 6)
	_gold_shop_popup.add_child(vbox)

	var title := Label.new()
	title.text = "GOLD SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Spend gold earned from combat on upgrades."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 21)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_gold_shop_balance_label = Label.new()
	_gold_shop_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_shop_balance_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_gold_shop_balance_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_gold_shop_list = VBoxContainer.new()
	_gold_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_shop_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_gold_shop_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func(): _gold_shop_popup.visible = false)
	vbox.add_child(close_btn)


func _open_gold_shop() -> void:
	menu_popup.visible = false
	_refresh_gold_shop()
	_gold_shop_popup.visible = true


func _refresh_gold_shop() -> void:
	for child in _gold_shop_list.get_children():
		child.queue_free()

	var gold := GameState.currencies.gold.balance
	_gold_shop_balance_label.text = "Gold: %d" % int(gold)

	for item in GOLD_SHOP_ITEMS:
		var bought: int = _gold_shop_purchases.get(item["id"], 0)
		var cost: float = float(item["cost"]) * pow(1.3, bought)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 21)
		lbl.text = "%s — %s (%.0fg)" % [item["name"], item["desc"], cost]
		if bought > 0:
			lbl.text += " [x%d]" % bought
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(60, 0)
		btn.disabled = (gold < cost)
		btn.pressed.connect(_on_buy_gold_item.bind(item, cost))
		row.add_child(btn)

		_gold_shop_list.add_child(row)


func _on_buy_gold_item(item: Dictionary, cost: float) -> void:
	if not GameState.currencies.gold.spend(cost):
		return

	match item["type"]:
		"stat_point":
			GameState.stat_points += int(item["value"])
		"exp":
			GameState.award_exp(item["value"])
		"attack":
			GameState.attack_skill += item["value"]
		"defense":
			GameState.defense_skill += item["value"]
		"hp":
			GameState.perm_hp_bonus += item["value"]
		"pl":
			GameState.currencies.power_level.earn(item["value"])
		"steps":
			GameState.currencies.pedometer.add_steps(item["value"])

	var bought: int = _gold_shop_purchases.get(item["id"], 0)
	_gold_shop_purchases[item["id"]] = bought + 1
	_refresh_gold_shop()


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
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Spend current Power Level on permanent upgrades.\nThese persist through Meditation."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 21)
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
		lbl.add_theme_font_size_override("font_size", 21)
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
#  MEDITATION (Prestige / Rebirth)
# ===========================================================================

const MEDITATION_MIN_SECONDS: float = 300.0  # 5 min minimum before allowing prestige

func _create_meditation_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_meditation_popup = PanelContainer.new()
	_meditation_popup.name = "MeditationPopup"
	_meditation_popup.visible = false
	_meditation_popup.layout_mode = 1
	_meditation_popup.anchors_preset = Control.PRESET_FULL_RECT
	_meditation_popup.anchor_left = 0.05
	_meditation_popup.anchor_top = 0.06
	_meditation_popup.anchor_right = 0.95
	_meditation_popup.anchor_bottom = 0.88
	_meditation_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_meditation_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 8)
	_meditation_popup.add_child(vbox)

	var title := Label.new()
	title.text = "PRESTIGE — MEDITATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sit on your mat and start anew — stronger than before."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_meditation_info_label = Label.new()
	_meditation_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meditation_info_label.add_theme_font_size_override("font_size", 21)
	_meditation_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_meditation_info_label)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	_meditate_confirm_btn = Button.new()
	_meditate_confirm_btn.text = "Begin Meditation"
	_meditate_confirm_btn.custom_minimum_size = Vector2(0, 48)
	_meditate_confirm_btn.pressed.connect(_do_meditation)
	vbox.add_child(_meditate_confirm_btn)

	var close_btn := Button.new()
	close_btn.text = "Not Yet"
	close_btn.pressed.connect(func(): _meditation_popup.visible = false)
	vbox.add_child(close_btn)

	# Cutscene overlay (full-screen, hidden by default)
	_cutscene_overlay = ColorRect.new()
	_cutscene_overlay.name = "CutsceneOverlay"
	_cutscene_overlay.visible = false
	_cutscene_overlay.layout_mode = 1
	_cutscene_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_cutscene_overlay.color = Color(0, 0, 0, 0)
	_cutscene_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_cutscene_overlay)

	_cutscene_label = Label.new()
	_cutscene_label.layout_mode = 1
	_cutscene_label.anchors_preset = Control.PRESET_CENTER
	_cutscene_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cutscene_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cutscene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cutscene_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cutscene_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cutscene_label.add_theme_font_size_override("font_size", 36)
	_cutscene_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_cutscene_label.custom_minimum_size = Vector2(300, 200)
	_cutscene_label.text = ""
	_cutscene_overlay.add_child(_cutscene_label)


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
	text += "Meditation is a rebirth. Your Power Level resets to 1,\n"
	text += "but your PL growth becomes permanently faster.\n"
	text += "The longer you wait between rebirths, the greater the reward.\n\n"
	text += "Current PL: %d\n" % int(pl)
	text += "Session length: %.0f min\n" % time_min
	text += "Session strength: %.0f%%\n" % time_pct
	text += "Growth multiplier: x%.2f\n" % GameState.meditation_multiplier
	text += "Gain if you prestige now: +%.3f\n" % multiplier_gain
	text += "Total rebirths: %d\n\n" % GameState.meditation_count

	if time_sec < MEDITATION_MIN_SECONDS:
		var remaining := (MEDITATION_MIN_SECONDS - time_sec) / 60.0
		text += "Too soon! You must wait %.0f more min before meditating.\n" % remaining
	elif time_min < 15:
		text += "Very low reward. Keep training for a better bonus.\n"
	elif time_min < 30:
		text += "Reward is growing. 30+ min for a solid bonus.\n"
	elif time_min < 60:
		text += "Good session! Solid growth reward.\n"
	else:
		text += "Excellent patience! Near-maximum reward.\n"

	text += "\nKEPT: Attack, Defense, Skills, Steps, Gold, Mastery, PL Shop\n"
	text += "RESET: Power Level (to 1), Bosses, Environment"

	_meditation_info_label.text = text

	# Anti-spam: disable button if session is too short
	if _meditate_confirm_btn:
		if time_sec < MEDITATION_MIN_SECONDS:
			_meditate_confirm_btn.disabled = true
			_meditate_confirm_btn.text = "Too Soon (%.0f min left)" % ((MEDITATION_MIN_SECONDS - time_sec) / 60.0)
		else:
			_meditate_confirm_btn.disabled = false
			_meditate_confirm_btn.text = "Begin Meditation"


func _do_meditation() -> void:
	_meditation_popup.visible = false
	# Play cutscene: fade to black → show text → perform reset → show result → fade back
	_play_prestige_cutscene()


func _play_prestige_cutscene() -> void:
	_cutscene_overlay.visible = true
	_cutscene_overlay.color = Color(0, 0, 0, 0)
	_cutscene_label.text = ""

	var tween := create_tween()

	# Phase 1: Fade to black (1s)
	tween.tween_property(_cutscene_overlay, "color", Color(0, 0, 0, 1), 1.0)

	# Phase 2: Show meditation text sequence
	tween.tween_callback(func(): _cutscene_label.text = "You sit on the mat...")
	tween.tween_interval(1.5)
	tween.tween_callback(func(): _cutscene_label.text = "You close your eyes...\nYour power fades away...")
	tween.tween_interval(1.5)

	# Phase 3: Perform the actual reset
	tween.tween_callback(func():
		var result := GameState.perform_meditation()
		var gain: float = result["multiplier_gained"]
		var new_mult: float = result["new_multiplier"]
		_cutscene_label.text = "A new strength awakens within you.\n\nGrowth multiplier: +%.3f\nNew multiplier: x%.2f\n\nYour journey begins again." % [gain, new_mult]
	)
	tween.tween_interval(3.0)

	# Phase 4: Fade back (1s)
	tween.tween_property(_cutscene_overlay, "color", Color(0, 0, 0, 0), 1.0)
	tween.tween_callback(func():
		_cutscene_overlay.visible = false
		_cutscene_label.text = ""
		_switch_to(ViewMode.OVERWORLD)
	)


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
	if _travel_popup:
		_travel_popup.visible = false
	if _gold_shop_popup:
		_gold_shop_popup.visible = false
	if _pl_shop_popup:
		_pl_shop_popup.visible = false
	if _meditation_popup:
		_meditation_popup.visible = false
	if _cutscene_overlay:
		_cutscene_overlay.visible = false
	if _augment_popup:
		_augment_popup.visible = false
	if _master_dialogue_popup:
		_master_dialogue_popup.visible = false


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
	alloc_title.add_theme_font_size_override("font_size", 27)
	steps_shop_list.add_child(alloc_title)

	var alloc_desc := Label.new()
	alloc_desc.text = "Choose where your walking steps go:"
	alloc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alloc_desc.add_theme_font_size_override("font_size", 21)
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
	_step_alloc_label.add_theme_font_size_override("font_size", 21)
	steps_shop_list.add_child(_step_alloc_label)

	var sep := HSeparator.new()
	steps_shop_list.add_child(sep)

	var shop_title := Label.new()
	shop_title.text = "STEP SHOP"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.add_theme_font_size_override("font_size", 27)
	steps_shop_list.add_child(shop_title)

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
#  AUGMENTS / ENERGY SYSTEM
# ===========================================================================

func _add_augment_menu_button() -> void:
	var menu_vbox := menu_popup.get_node_or_null("MenuVBox")
	if menu_vbox == null:
		return
	# Insert after Character Stats (index 1), or find Travel and insert before it
	var travel_idx := -1
	for i in menu_vbox.get_child_count():
		if menu_vbox.get_child(i) == travel_menu_btn:
			travel_idx = i
			break
	var aug_btn := Button.new()
	aug_btn.name = "AugmentBtn"
	aug_btn.text = "Augments"
	aug_btn.pressed.connect(_open_augments)
	menu_vbox.add_child(aug_btn)
	if travel_idx >= 0:
		menu_vbox.move_child(aug_btn, travel_idx)


func _create_augment_popup() -> void:
	var ui_root: Control = $UILayer/UI

	_augment_popup = PanelContainer.new()
	_augment_popup.name = "AugmentPopup"
	_augment_popup.visible = false
	_augment_popup.layout_mode = 1
	_augment_popup.anchors_preset = Control.PRESET_FULL_RECT
	_augment_popup.anchor_left = 0.02
	_augment_popup.anchor_top = 0.04
	_augment_popup.anchor_right = 0.98
	_augment_popup.anchor_bottom = 0.90
	_augment_popup.add_theme_stylebox_override("panel", _make_panel_style())
	ui_root.add_child(_augment_popup)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 4)
	_augment_popup.add_child(vbox)

	var title := Label.new()
	title.text = "AUGMENTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _fs(27))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Allocate energy to train or power up augments."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", _fs(18))
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	# Energy info
	_energy_info_label = Label.new()
	_energy_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_info_label.add_theme_font_size_override("font_size", _fs(21))
	vbox.add_child(_energy_info_label)

	# Input row
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)

	var input_lbl := Label.new()
	input_lbl.text = "Input:"
	input_lbl.add_theme_font_size_override("font_size", _fs(18))
	input_row.add_child(input_lbl)

	_energy_input = LineEdit.new()
	_energy_input.text = "10"
	_energy_input.custom_minimum_size = Vector2(80, 0)
	_energy_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(_energy_input)

	var cap_btn := Button.new()
	cap_btn.text = "Cap"
	cap_btn.add_theme_font_size_override("font_size", _fs(16))
	cap_btn.pressed.connect(func(): _energy_input.text = "%d" % int(GameState.energy.idle))
	input_row.add_child(cap_btn)

	var half_btn := Button.new()
	half_btn.text = "1/2"
	half_btn.add_theme_font_size_override("font_size", _fs(16))
	half_btn.pressed.connect(func(): _energy_input.text = "%d" % int(GameState.energy.idle / 2.0))
	input_row.add_child(half_btn)

	var quarter_btn := Button.new()
	quarter_btn.text = "1/4"
	quarter_btn.add_theme_font_size_override("font_size", _fs(16))
	quarter_btn.pressed.connect(func(): _energy_input.text = "%d" % int(GameState.energy.idle / 4.0))
	input_row.add_child(quarter_btn)

	vbox.add_child(input_row)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scrollable augment list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_augment_list = VBoxContainer.new()
	_augment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_augment_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_augment_list)

	# Augment ATK/DEF multiplier display
	var mult_label := Label.new()
	mult_label.name = "MultLabel"
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mult_label.add_theme_font_size_override("font_size", _fs(18))
	vbox.add_child(mult_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.add_theme_font_size_override("font_size", _fs(21))
	close_btn.pressed.connect(func(): _augment_popup.visible = false)
	vbox.add_child(close_btn)


func _open_augments() -> void:
	menu_popup.visible = false
	_refresh_augment_panel()
	_augment_popup.visible = true


func _get_energy_input_value() -> float:
	if _energy_input == null:
		return 10.0
	var val := _energy_input.text.to_float()
	return maxf(val, 0.0)


func _refresh_augment_panel() -> void:
	if _augment_list == null:
		return

	for child in _augment_list.get_children():
		child.queue_free()

	var e := GameState.energy

	# Update energy info
	_energy_info_label.text = "Energy: %.0f Idle / %.0f Cap  |  Power: %.1f" % [e.idle, e.cap, e.power]

	# ATK/DEF training rows
	_add_energy_training_row("Attack Training", e.allocated_attack, "_atk")
	_add_energy_training_row("Defense Training", e.allocated_defense, "_def")

	var sep := HSeparator.new()
	_augment_list.add_child(sep)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var h_name := Label.new()
	h_name.text = "Name"
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_name.add_theme_font_size_override("font_size", _fs(16))
	h_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(h_name)
	var h_energy := Label.new()
	h_energy.text = "Energy"
	h_energy.add_theme_font_size_override("font_size", _fs(16))
	h_energy.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	h_energy.custom_minimum_size = Vector2(60, 0)
	header.add_child(h_energy)
	var h_level := Label.new()
	h_level.text = "Lv"
	h_level.add_theme_font_size_override("font_size", _fs(16))
	h_level.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	h_level.custom_minimum_size = Vector2(40, 0)
	header.add_child(h_level)
	_augment_list.add_child(header)

	# Augment rows
	for i in Augments.AUGMENT_DEFS.size():
		var def_data: Dictionary = Augments.AUGMENT_DEFS[i]
		var aug: Augments.AugmentState = e.augments[i]
		var unlocked := GameState.player_level >= int(def_data["unlock_level"])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", _fs(18))
		if not unlocked:
			name_lbl.text = "Locked (Lv.%d)" % int(def_data["unlock_level"])
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif not aug.started:
			name_lbl.text = "%s (%dg)" % [def_data["name"], int(def_data["gold_cost"])]
		else:
			name_lbl.text = def_data["name"]
		row.add_child(name_lbl)

		# +/- buttons
		var add_btn := Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(32, 0)
		add_btn.add_theme_font_size_override("font_size", _fs(18))
		row.add_child(add_btn)

		var sub_btn := Button.new()
		sub_btn.text = "-"
		sub_btn.custom_minimum_size = Vector2(32, 0)
		sub_btn.add_theme_font_size_override("font_size", _fs(18))
		row.add_child(sub_btn)

		# Energy allocated display
		var alloc_lbl := Label.new()
		alloc_lbl.add_theme_font_size_override("font_size", _fs(18))
		alloc_lbl.custom_minimum_size = Vector2(60, 0)
		alloc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(alloc_lbl)

		# Level display
		var level_lbl := Label.new()
		level_lbl.add_theme_font_size_override("font_size", _fs(18))
		level_lbl.custom_minimum_size = Vector2(40, 0)
		level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(level_lbl)

		if not unlocked:
			add_btn.disabled = true
			sub_btn.disabled = true
			alloc_lbl.text = "0"
			level_lbl.text = "0"
		elif not aug.started:
			# Need to buy first
			add_btn.text = "Buy"
			add_btn.custom_minimum_size = Vector2(52, 0)
			add_btn.pressed.connect(_on_buy_augment.bind(i))
			sub_btn.visible = false
			alloc_lbl.text = "0"
			level_lbl.text = "0"
			if GameState.currencies.gold.balance < float(def_data["gold_cost"]):
				add_btn.disabled = true
		else:
			alloc_lbl.text = "%.0f" % aug.energy_allocated
			level_lbl.text = "%d" % aug.level
			add_btn.pressed.connect(_on_add_augment_energy.bind(i))
			sub_btn.pressed.connect(_on_sub_augment_energy.bind(i))

		_augment_list.add_child(row)

	# Update multiplier display
	var mults := Augments.total_augment_multiplier(e)
	var mult_node := _augment_popup.get_node_or_null("*/MultLabel")
	if mult_node == null:
		# Find it manually
		for child in _augment_popup.get_child(0).get_children():
			if child.name == "MultLabel":
				mult_node = child
				break
	if mult_node:
		mult_node.text = "Total ATK Mult: x%.2f  |  DEF Mult: x%.2f" % [float(mults["attack"]), float(mults["defense"])]


func _add_energy_training_row(label_text: String, allocated: float, tag: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", _fs(18))
	row.add_child(lbl)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(32, 0)
	add_btn.add_theme_font_size_override("font_size", _fs(18))
	row.add_child(add_btn)

	var sub_btn := Button.new()
	sub_btn.text = "-"
	sub_btn.custom_minimum_size = Vector2(32, 0)
	sub_btn.add_theme_font_size_override("font_size", _fs(18))
	row.add_child(sub_btn)

	var alloc_lbl := Label.new()
	alloc_lbl.text = "%.0f" % allocated
	alloc_lbl.add_theme_font_size_override("font_size", _fs(18))
	alloc_lbl.custom_minimum_size = Vector2(60, 0)
	alloc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(alloc_lbl)

	if tag == "_atk":
		add_btn.pressed.connect(_on_add_attack_energy)
		sub_btn.pressed.connect(_on_sub_attack_energy)
	else:
		add_btn.pressed.connect(_on_add_defense_energy)
		sub_btn.pressed.connect(_on_sub_defense_energy)

	_augment_list.add_child(row)


func _on_add_attack_energy() -> void:
	var amount := _get_energy_input_value()
	GameState.energy.allocate_to_attack(amount)
	_refresh_augment_panel()


func _on_sub_attack_energy() -> void:
	var amount := _get_energy_input_value()
	GameState.energy.deallocate_from_attack(amount)
	_refresh_augment_panel()


func _on_add_defense_energy() -> void:
	var amount := _get_energy_input_value()
	GameState.energy.allocate_to_defense(amount)
	_refresh_augment_panel()


func _on_sub_defense_energy() -> void:
	var amount := _get_energy_input_value()
	GameState.energy.deallocate_from_defense(amount)
	_refresh_augment_panel()


func _on_add_augment_energy(aug_index: int) -> void:
	var amount := _get_energy_input_value()
	GameState.energy.allocate_to_augment(aug_index, amount)
	_refresh_augment_panel()


func _on_sub_augment_energy(aug_index: int) -> void:
	var amount := _get_energy_input_value()
	GameState.energy.deallocate_from_augment(aug_index, amount)
	_refresh_augment_panel()


func _on_buy_augment(aug_index: int) -> void:
	if aug_index < 0 or aug_index >= Augments.AUGMENT_DEFS.size():
		return
	var def_data: Dictionary = Augments.AUGMENT_DEFS[aug_index]
	var cost: float = float(def_data["gold_cost"])
	if not GameState.currencies.gold.spend(cost):
		return
	GameState.energy.augments[aug_index].started = true
	_refresh_augment_panel()


# ===========================================================================
#  HELPERS
# ===========================================================================

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


# ===========================================================================
#  FONT SCALE HELPER
# ===========================================================================

func _fs(base: int) -> int:
	return maxi(int(base * _font_scale), 8)


func _apply_menu_font_sizes() -> void:
	var menu_vbox := menu_popup.get_node_or_null("MenuVBox")
	if menu_vbox == null:
		return
	for child in menu_vbox.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", _fs(27))
		elif child is Button:
			child.add_theme_font_size_override("font_size", _fs(21))


func _setup_font_settings() -> void:
	var settings_vbox := settings_popup.get_node_or_null("SettingsVBox")
	if settings_vbox == null:
		return

	# Insert font size controls before the Close button
	var close_btn := settings_vbox.get_node_or_null("CloseBtn")
	var close_idx := -1
	if close_btn:
		close_idx = close_btn.get_index()

	var sep := HSeparator.new()
	sep.name = "FontSep"
	settings_vbox.add_child(sep)
	if close_idx >= 0:
		settings_vbox.move_child(sep, close_idx)
		close_idx += 1

	var font_label := Label.new()
	font_label.name = "FontLabel"
	font_label.text = "Font Size"
	font_label.add_theme_font_size_override("font_size", _fs(21))
	settings_vbox.add_child(font_label)
	if close_idx >= 0:
		settings_vbox.move_child(font_label, close_idx)
		close_idx += 1

	var hbox := HBoxContainer.new()
	hbox.name = "FontHBox"
	hbox.add_theme_constant_override("separation", 8)
	settings_vbox.add_child(hbox)
	if close_idx >= 0:
		settings_vbox.move_child(hbox, close_idx)

	_font_slider = HSlider.new()
	_font_slider.min_value = 0.6
	_font_slider.max_value = 2.5
	_font_slider.step = 0.1
	_font_slider.value = _font_scale
	_font_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_slider.value_changed.connect(_on_font_scale_changed)
	hbox.add_child(_font_slider)

	_font_value_label = Label.new()
	_font_value_label.text = "%.0f%%" % (_font_scale * 100.0)
	_font_value_label.add_theme_font_size_override("font_size", _fs(21))
	_font_value_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(_font_value_label)


func _on_font_scale_changed(value: float) -> void:
	_font_scale = value
	if _font_value_label:
		_font_value_label.text = "%.0f%%" % (_font_scale * 100.0)

	# Apply to all existing controls recursively
	_scale_fonts_recursive($UILayer/UI)

	# Rebuild dynamic popups to pick up new scale
	_apply_menu_font_sizes()


func _scale_fonts_recursive(node: Node) -> void:
	if node is Control:
		if node.has_theme_font_size_override("font_size"):
			if not node.has_meta("_base_fs"):
				node.set_meta("_base_fs", node.get_theme_font_size("font_size"))
			var base: int = node.get_meta("_base_fs")
			node.add_theme_font_size_override("font_size", _fs(base))
	for child in node.get_children():
		_scale_fonts_recursive(child)
