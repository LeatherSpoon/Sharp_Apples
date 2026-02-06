class_name Encounter
## Combat Encounter state machine.
##
## Phase flow: Intro → Active → Victory/Defeat → Exiting
## Handles opponent definitions, damage tracking, loot rolls, rewards.

enum Phase {
	INTRO,
	ACTIVE,
	VICTORY,
	DEFEAT,
	EXITING,
}


class OpponentDefinition:
	var id: String
	var opponent_name: String
	var base_power: float
	var base_hp: float
	var base_damage: float
	var attack_speed: float
	var gold_reward: float
	var pl_reward: float
	var mastery_xp_reward: float
	var loot_table: Array[Dictionary] = []  # { item_id, drop_rate, min_qty, max_qty }
	var environment_id: String
	var is_boss: bool


class State:
	var phase: int = Phase.INTRO
	var opponent: OpponentDefinition
	var player_hp: float
	var player_max_hp: float
	var opponent_hp: float
	var player_theme: int
	var player_damage_dealt: float = 0.0
	var opponent_damage_dealt: float = 0.0
	var elapsed_time: float = 0.0
	var loot_drops: Array[Dictionary] = []

	func _init(
		opp: OpponentDefinition,
		p_hp: float,
		p_max_hp: float,
		theme: int,
	) -> void:
		opponent = opp
		player_hp = p_hp
		player_max_hp = p_max_hp
		opponent_hp = opp.base_hp
		player_theme = theme

	func begin_combat() -> void:
		phase = Phase.ACTIVE

	func damage_opponent(amount: float) -> float:
		if amount <= 0:
			return opponent_hp
		opponent_hp = maxf(opponent_hp - amount, 0.0)
		player_damage_dealt += amount
		return opponent_hp

	func damage_player(amount: float) -> float:
		if amount <= 0:
			return player_hp
		player_hp = maxf(player_hp - amount, 0.0)
		opponent_damage_dealt += amount
		return player_hp

	func check_resolution() -> int:
		if phase != Phase.ACTIVE:
			return phase
		if opponent_hp <= 0:
			phase = Phase.VICTORY
		elif player_hp <= 0:
			phase = Phase.DEFEAT
		return phase

	func exit_encounter() -> void:
		phase = Phase.EXITING

	func calculate_rewards() -> Dictionary:
		if phase != Phase.VICTORY:
			return { "gold": 0.0, "power_level_gain": 0.0, "mastery_xp": 0.0, "loot": [] }
		loot_drops = Encounter.roll_loot(opponent.loot_table)
		return {
			"gold": opponent.gold_reward,
			"power_level_gain": opponent.pl_reward,
			"mastery_xp": opponent.mastery_xp_reward,
			"loot": loot_drops,
		}


static func roll_loot(loot_table: Array, rng_func: Callable = Callable()) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	for entry in loot_table:
		var roll: float
		if rng_func.is_valid():
			roll = rng_func.call()
		else:
			roll = randf()
		if roll >= entry["drop_rate"]:
			continue
		var qty_roll: float
		if rng_func.is_valid():
			qty_roll = rng_func.call()
		else:
			qty_roll = randf()
		var min_qty: int = entry["min_qty"]
		var max_qty: int = entry["max_qty"]
		var quantity: int = min_qty + int(qty_roll * (max_qty - min_qty + 1))
		quantity = mini(quantity, max_qty)
		drops.append({ "item_id": entry["item_id"], "quantity": quantity })
	return drops
