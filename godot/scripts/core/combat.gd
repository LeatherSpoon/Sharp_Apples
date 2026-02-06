class_name Combat
## Combat Themes, Mastery, and Damage formulas.
##
## Theme cycle: Unarmed → Armed → Ranged → Energy.
## Only one active at a time, forced by environment progression.


# ---- Enums ----

enum Theme {
	UNARMED,
	ARMED,
	RANGED,
	ENERGY,
}

const THEME_ORDER: Array[int] = [Theme.UNARMED, Theme.ARMED, Theme.RANGED, Theme.ENERGY]
const MAX_MASTERY_LEVEL: int = 100

const THEME_DEFINITIONS: Dictionary = {
	Theme.UNARMED: {
		"name": "Unarmed",
		"base_damage": 10.0,
		"primary_variable": Variables.Kind.STRENGTH,
		"theme_key": "unarmed",
	},
	Theme.ARMED: {
		"name": "Armed",
		"base_damage": 15.0,
		"primary_variable": Variables.Kind.STRENGTH,
		"theme_key": "armed",
	},
	Theme.RANGED: {
		"name": "Ranged",
		"base_damage": 12.0,
		"primary_variable": Variables.Kind.DEXTERITY,
		"theme_key": "ranged",
	},
	Theme.ENERGY: {
		"name": "Energy",
		"base_damage": 20.0,
		"primary_variable": Variables.Kind.FOCUS,
		"theme_key": "energy",
	},
}


# ---- Mastery ----

class ThemeMastery:
	var level: int = 0
	var xp: float = 0.0
	var total_xp: float = 0.0


class MasteryState:
	var themes: Dictionary = {}

	func _init() -> void:
		for theme in THEME_ORDER:
			themes[theme] = ThemeMastery.new()

	func award_xp(theme: int, amount: float) -> bool:
		var mastery: ThemeMastery = themes[theme]
		if mastery.level >= MAX_MASTERY_LEVEL:
			return false
		mastery.xp += amount
		mastery.total_xp += amount
		var required := mastery_xp_required(mastery.level)
		var leveled := false
		while mastery.xp >= required and mastery.level < MAX_MASTERY_LEVEL:
			mastery.xp -= required
			mastery.level += 1
			required = mastery_xp_required(mastery.level)
			leveled = true
		return leveled


static func next_theme_in_cycle(current: int) -> int:
	var idx := THEME_ORDER.find(current)
	return THEME_ORDER[(idx + 1) % THEME_ORDER.size()]


## XP required for a given mastery level: 100 * 1.15^level
static func mastery_xp_required(level: int) -> float:
	return 100.0 * pow(1.15, level)


## Cross-theme mastery bonus: average mastery of other themes * 0.02
static func cross_theme_mastery_bonus(mastery: MasteryState, active_theme: int) -> float:
	var total := 0.0
	var count := 0
	for theme in THEME_ORDER:
		if theme != active_theme:
			total += mastery.themes[theme].level
			count += 1
	if count == 0:
		return 0.0
	return (total / count) * 0.02


## Main damage formula:
## BaseDamage × (1 + EffectivePL/100) × ThemeMultiplier × (1 + VarScaling) × (1 + CrossBonus)
static func calculate_damage(
	base_damage: float,
	effective_pl: float,
	variable_scaling: float,
	cross_theme_bonus: float,
	theme_multiplier: float,
) -> float:
	return (
		base_damage
		* (1.0 + effective_pl / 100.0)
		* theme_multiplier
		* (1.0 + variable_scaling)
		* (1.0 + cross_theme_bonus)
	)


## Tournament opponent power: BasePower × 1.05^victories × envTier
static func tournament_opponent_power(
	base_power: float,
	victories: int,
	env_tier: int,
) -> float:
	return base_power * pow(1.05, victories) * env_tier


## Expected loss check: player effective PL < opponent power × 1.5
static func is_expected_loss(effective_pl: float, opponent_power: float) -> bool:
	return effective_pl < opponent_power * 1.5
