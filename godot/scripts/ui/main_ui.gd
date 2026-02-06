extends Node
## Main scene controller — manages the top banner, bottom nav,
## content switching (overworld / training / combat / gear), stat display,
## menu popups, EXP/level bar, stat allocation, and virtual joystick.

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

# ---- Virtual Joystick ----
@onready var virtual_joystick: Control = %VirtualJoystick
@onready var player_node: CharacterBody2D = $World/Player

enum ViewMode { OVERWORLD, TRAINING, COMBAT, GEAR }
var _current_view: int = ViewMode.OVERWORLD


func _ready() -> void:
	# Bottom nav
	overworld_btn.pressed.connect(_switch_to.bind(ViewMode.OVERWORLD))
	train_btn.pressed.connect(_switch_to.bind(ViewMode.TRAINING))
	fight_btn.pressed.connect(_start_random_encounter)
	gear_btn.pressed.connect(_switch_to.bind(ViewMode.GEAR))

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
	pedometer_btn.pressed.connect(_on_pedometer_pressed)
	master_reset_btn.pressed.connect(_on_master_reset_pressed)

	# Combat
	combat_view.combat_finished.connect(_on_combat_finished)
	combat_view.combat_fled.connect(_on_combat_fled)

	# Virtual joystick
	virtual_joystick.joystick_input.connect(_on_joystick_input)

	_switch_to(ViewMode.OVERWORLD)
	_build_gear_shop()
	_build_stats_list()
	_build_mastery_list()


func _process(_delta: float) -> void:
	_update_banner()
	_update_stats()
	_update_exp_bar()


func _update_banner() -> void:
	var eff_pl := GameState.currencies.effective_power_level()
	var perm := GameState.currencies.power_level.permanent

	if abs(_displayed_pl - eff_pl) > 0.5:
		_displayed_pl = lerpf(_displayed_pl, eff_pl, 0.15)
	else:
		_displayed_pl = eff_pl

	power_level_value.text = "%d" % int(_displayed_pl)

	if perm > 0:
		power_level_label.text = "POWER LEVEL (+%d perm)" % int(perm)
	else:
		power_level_label.text = "POWER LEVEL"


func _update_stats() -> void:
	gold_label.text = "Gold: %d" % int(GameState.currencies.gold.balance)
	env_label.text = GameState.environment.current_environment_name()
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
	virtual_joystick.visible = (view == ViewMode.OVERWORLD)
	overworld_btn.button_pressed = (view == ViewMode.OVERWORLD)
	train_btn.button_pressed = (view == ViewMode.TRAINING)
	gear_btn.button_pressed = (view == ViewMode.GEAR)
	_close_all_popups()


# ---- Virtual Joystick ----

func _on_joystick_input(direction: Vector2) -> void:
	if player_node:
		player_node.set_joystick_direction(direction)


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
		var btn: Button = row.get_node("AddBtn")
		lbl.text = "%s: %.0f" % [stat_names[kind], GameState.variables.get_value(kind)]
		btn.disabled = (GameState.stat_points <= 0)
		idx += 1


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


func _on_pedometer_pressed() -> void:
	menu_popup.visible = false
	var result := GameState.spend_pedometer_for_upgrade()
	if result["steps_spent"] > 0:
		pass  # Upgrade applied


func _on_master_reset_pressed() -> void:
	menu_popup.visible = false
	GameState.perform_master_reset()


# ---- Gear Shop ----

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
