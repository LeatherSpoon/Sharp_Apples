class_name Variables
## Controlling Variables — stats that drive combat scaling,
## trainable through laborious activities.
##
## Strength   (Mining, Lumberjacking)    → Unarmed/Armed damage
## Dexterity  (Obstacle Courses)         → Ranged accuracy, Armed speed
## Focus      (Meditation)               → Energy capacity, Ranged range
## Endurance  (Distance Running, Farming) → HP, all-theme defense
## Luck       (Fishing)                  → Crit chance, loot quality


# ---- Enums ----

enum Kind {
	STRENGTH,
	DEXTERITY,
	FOCUS,
	ENDURANCE,
	LUCK,
}

enum TrainingActivity {
	MINING,
	OBSTACLE_COURSE,
	MEDITATION,
	DISTANCE_RUNNING,
	LUMBERJACKING,
	FISHING,
	FARMING,
}

enum TrainingIntensity {
	CASUAL = 10,
	FOCUSED = 25,
	DEEP = 50,
}


# ---- Activity → Variable mapping ----

const ACTIVITY_VARIABLE_MAP: Dictionary = {
	TrainingActivity.MINING: Kind.STRENGTH,
	TrainingActivity.LUMBERJACKING: Kind.STRENGTH,
	TrainingActivity.OBSTACLE_COURSE: Kind.DEXTERITY,
	TrainingActivity.MEDITATION: Kind.FOCUS,
	TrainingActivity.DISTANCE_RUNNING: Kind.ENDURANCE,
	TrainingActivity.FARMING: Kind.ENDURANCE,
	TrainingActivity.FISHING: Kind.LUCK,
}


# ---- Per-point effects per theme ----
# Keys: "unarmed", "armed", "ranged", "energy"

const VARIABLE_EFFECTS: Dictionary = {
	Kind.STRENGTH: { "unarmed": 0.02, "armed": 0.02, "ranged": 0.005, "energy": 0.005 },
	Kind.DEXTERITY: { "unarmed": 0.005, "armed": 0.005, "ranged": 0.01, "energy": 0.005 },
	Kind.FOCUS: { "unarmed": 0.005, "armed": 0.005, "ranged": 0.005, "energy": 0.01 },
	Kind.ENDURANCE: { "unarmed": 0.005, "armed": 0.005, "ranged": 0.005, "energy": 0.01 },
	Kind.LUCK: { "unarmed": 0.002, "armed": 0.002, "ranged": 0.002, "energy": 0.002 },
}


# ---- Controlling Variables state ----

class State:
	var values: Dictionary = {
		Kind.STRENGTH: 0.0,
		Kind.DEXTERITY: 0.0,
		Kind.FOCUS: 0.0,
		Kind.ENDURANCE: 0.0,
		Kind.LUCK: 0.0,
	}

	func get_value(kind: int) -> float:
		return values.get(kind, 0.0)

	func train(kind: int, amount: float) -> void:
		if amount > 0:
			values[kind] = values.get(kind, 0.0) + amount

	## Total variable-scaling multiplier for a given combat theme key.
	func variable_scaling(theme_key: String) -> float:
		var total := 0.0
		for kind in VARIABLE_EFFECTS:
			total += values.get(kind, 0.0) * VARIABLE_EFFECTS[kind][theme_key]
		return total


# ---- Derived stats ----

const BASE_HP: int = 100
const BASE_ENERGY_POOL: int = 100
const BASE_ENERGY_REGEN: float = 5.0
const BASE_CRIT_CHANCE: float = 0.05
const CRIT_CHANCE_PER_LUCK: float = 0.005
const MAX_CRIT_CHANCE: float = 0.5


static func max_hp(endurance: float) -> float:
	return BASE_HP + endurance


static func energy_pool_size(focus: float) -> float:
	return BASE_ENERGY_POOL + focus * 5.0


static func energy_regen_rate(focus: float) -> float:
	return BASE_ENERGY_REGEN + focus * 0.5


static func crit_chance(luck: float) -> float:
	return minf(BASE_CRIT_CHANCE + luck * CRIT_CHANCE_PER_LUCK, MAX_CRIT_CHANCE)


static func loot_quality_multiplier(luck: float) -> float:
	return 1.0 + luck * 0.01
