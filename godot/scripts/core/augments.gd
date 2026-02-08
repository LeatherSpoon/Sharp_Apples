class_name Augments
## Energy & Augment system.
##
## Energy is a finite resource with a cap. The player allocates energy to:
##   - Attack Training (passively trains attack skill)
##   - Defense Training (passively trains defense skill)
##   - Individual Augments (level up over time, give ATK/DEF multipliers)
##
## Competing priorities: you never have enough energy for everything.
## Augments cost gold to start and energy to level. Higher augment levels
## give bigger multipliers but take exponentially longer to level.


# ---- Augment Definitions ----

const AUGMENT_DEFS: Array[Dictionary] = [
	{ "id": "safety_scissors", "name": "Safety Scissors", "gold_cost": 50, "atk_mult_per_level": 0.05, "def_mult_per_level": 0.05, "unlock_level": 1 },
	{ "id": "rubber_band", "name": "Rubber Band", "gold_cost": 200, "atk_mult_per_level": 0.08, "def_mult_per_level": 0.03, "unlock_level": 3 },
	{ "id": "duct_tape", "name": "Duct Tape Armor", "gold_cost": 500, "atk_mult_per_level": 0.03, "def_mult_per_level": 0.10, "unlock_level": 5 },
	{ "id": "milk_jug", "name": "Milk Jug Weights", "gold_cost": 1000, "atk_mult_per_level": 0.12, "def_mult_per_level": 0.04, "unlock_level": 8 },
	{ "id": "pool_noodle", "name": "Pool Noodle", "gold_cost": 2500, "atk_mult_per_level": 0.07, "def_mult_per_level": 0.07, "unlock_level": 10 },
	{ "id": "traffic_cone", "name": "Traffic Cone Helm", "gold_cost": 5000, "atk_mult_per_level": 0.04, "def_mult_per_level": 0.15, "unlock_level": 14 },
	{ "id": "garden_hose", "name": "Garden Hose Whip", "gold_cost": 10000, "atk_mult_per_level": 0.18, "def_mult_per_level": 0.05, "unlock_level": 18 },
	{ "id": "shopping_cart", "name": "Shopping Cart Shield", "gold_cost": 25000, "atk_mult_per_level": 0.06, "def_mult_per_level": 0.20, "unlock_level": 22 },
	{ "id": "trampoline", "name": "Trampoline", "gold_cost": 50000, "atk_mult_per_level": 0.15, "def_mult_per_level": 0.15, "unlock_level": 28 },
	{ "id": "lawnmower", "name": "Riding Lawnmower", "gold_cost": 100000, "atk_mult_per_level": 0.25, "def_mult_per_level": 0.25, "unlock_level": 35 },
]


# ---- Augment Instance State ----

class AugmentState:
	var id: String = ""
	var level: int = 0
	var xp: float = 0.0
	var energy_allocated: float = 0.0
	var started: bool = false  # true once gold is spent to activate


# ---- Energy State ----

class EnergyState:
	var cap: float = 100.0
	var idle: float = 100.0    # unallocated energy (cap - all allocations)
	var power: float = 1.0     # multiplier on energy effectiveness
	var allocated_attack: float = 0.0
	var allocated_defense: float = 0.0
	var augments: Array[AugmentState] = []

	func _init() -> void:
		for def in AUGMENT_DEFS:
			var aug := AugmentState.new()
			aug.id = def["id"]
			augments.append(aug)

	func total_allocated() -> float:
		var total := allocated_attack + allocated_defense
		for aug in augments:
			total += aug.energy_allocated
		return total

	func recalc_idle() -> void:
		idle = maxf(cap - total_allocated(), 0.0)

	## Try to allocate energy to attack training. Returns actual amount allocated.
	func allocate_to_attack(amount: float) -> float:
		var actual := minf(amount, idle)
		if actual <= 0:
			return 0.0
		allocated_attack += actual
		recalc_idle()
		return actual

	## Try to allocate energy to defense training. Returns actual amount allocated.
	func allocate_to_defense(amount: float) -> float:
		var actual := minf(amount, idle)
		if actual <= 0:
			return 0.0
		allocated_defense += actual
		recalc_idle()
		return actual

	## Try to allocate energy to an augment. Returns actual amount allocated.
	func allocate_to_augment(aug_index: int, amount: float) -> float:
		if aug_index < 0 or aug_index >= augments.size():
			return 0.0
		var actual := minf(amount, idle)
		if actual <= 0:
			return 0.0
		augments[aug_index].energy_allocated += actual
		recalc_idle()
		return actual

	## Remove energy from attack training.
	func deallocate_from_attack(amount: float) -> float:
		var actual := minf(amount, allocated_attack)
		allocated_attack -= actual
		recalc_idle()
		return actual

	## Remove energy from defense training.
	func deallocate_from_defense(amount: float) -> float:
		var actual := minf(amount, allocated_defense)
		allocated_defense -= actual
		recalc_idle()
		return actual

	## Remove energy from an augment.
	func deallocate_from_augment(aug_index: int, amount: float) -> float:
		if aug_index < 0 or aug_index >= augments.size():
			return 0.0
		var actual := minf(amount, augments[aug_index].energy_allocated)
		augments[aug_index].energy_allocated -= actual
		recalc_idle()
		return actual


# ---- XP / Leveling ----

## XP required for a given augment level.
## Each level takes 10x as long as the previous (base time increases with level).
static func augment_xp_required(level: int) -> float:
	return 50.0 * pow(1.0 + level, 2)


## Gold cost for upgrading an augment (unlocking the next upgrade tier).
## Scales with square of upgrade count.
static func augment_upgrade_gold_cost(base_gold: float, upgrade_count: int) -> float:
	return base_gold * pow(1.0 + upgrade_count, 2)


## Tick augments and energy training. Called each frame from GameState.
static func tick(energy: EnergyState, delta: float, player_level: int) -> Dictionary:
	var results := {
		"attack_trained": 0.0,
		"defense_trained": 0.0,
		"augments_leveled": [],
	}

	# Attack training: energy allocated * power * delta → skill gain
	if energy.allocated_attack > 0:
		var gain := energy.allocated_attack * energy.power * delta * 0.001
		results["attack_trained"] = gain

	# Defense training: energy allocated * power * delta → skill gain
	if energy.allocated_defense > 0:
		var gain := energy.allocated_defense * energy.power * delta * 0.001
		results["defense_trained"] = gain

	# Augment XP ticking
	for i in energy.augments.size():
		var aug: AugmentState = energy.augments[i]
		if not aug.started or aug.energy_allocated <= 0:
			continue

		# XP gain = energy_allocated * energy_power * delta
		var xp_gain := aug.energy_allocated * energy.power * delta * 0.01
		aug.xp += xp_gain

		var required := augment_xp_required(aug.level)
		while aug.xp >= required:
			aug.xp -= required
			aug.level += 1
			required = augment_xp_required(aug.level)
			results["augments_leveled"].append(i)

	return results


## Calculate the total Attack/Defense multiplier from all augments.
static func total_augment_multiplier(energy: EnergyState) -> Dictionary:
	var atk_mult := 1.0
	var def_mult := 1.0
	for i in energy.augments.size():
		var aug: AugmentState = energy.augments[i]
		if aug.level <= 0:
			continue
		if i >= AUGMENT_DEFS.size():
			continue
		var def_data: Dictionary = AUGMENT_DEFS[i]
		atk_mult += aug.level * float(def_data["atk_mult_per_level"])
		def_mult += aug.level * float(def_data["def_mult_per_level"])
	return { "attack": atk_mult, "defense": def_mult }
