class_name Environment
## Environment definitions and progression.
##
## 5 authored environments, each cycling to the next combat theme.
## Defeat = progression: tournament loss advances to next master.

enum Phase {
	TRAINING,
	TOURNAMENT,
	TRANSITION,
}

const ENVIRONMENTS: Array[Dictionary] = [
	{
		"id": "forest_dojo",
		"name": "Forest Dojo",
		"tier": 1,
		"combat_theme": Combat.Theme.UNARMED,
		"description": "A tranquil woodland clearing where the first master teaches bare-handed combat.",
	},
	{
		"id": "iron_fortress",
		"name": "Iron Fortress",
		"tier": 2,
		"combat_theme": Combat.Theme.ARMED,
		"description": "A towering fortress of dark iron, where bladed weapons define survival.",
	},
	{
		"id": "wind_valley",
		"name": "Wind Valley",
		"tier": 3,
		"combat_theme": Combat.Theme.RANGED,
		"description": "Sweeping canyons with treacherous winds — perfect for ranged mastery.",
	},
	{
		"id": "crystal_spire",
		"name": "Crystal Spire",
		"tier": 4,
		"combat_theme": Combat.Theme.ENERGY,
		"description": "A crystalline tower pulsing with raw energy, where ki techniques reign.",
	},
	{
		"id": "desert_temple",
		"name": "Desert Temple",
		"tier": 5,
		"combat_theme": Combat.Theme.UNARMED,
		"description": "An ancient temple buried in sand. The cycle begins anew at greater power.",
	},
]


class EnvironmentProgress:
	var tournament_victories: int = 0
	var tournament_defeats: int = 0
	var phase: int = Phase.TRAINING


class ProgressionState:
	var current_index: int = 0
	var progress: Array[EnvironmentProgress] = []

	func _init() -> void:
		for i in ENVIRONMENTS.size():
			progress.append(EnvironmentProgress.new())

	func current_environment() -> Dictionary:
		return ENVIRONMENTS[current_index]

	func current_environment_name() -> String:
		return ENVIRONMENTS[current_index]["name"]

	func current_combat_theme() -> int:
		return ENVIRONMENTS[current_index]["combat_theme"]

	func advance() -> Dictionary:
		if current_index >= ENVIRONMENTS.size() - 1:
			return {}  # No more authored environments
		current_index += 1
		return ENVIRONMENTS[current_index]

	func record_victory() -> void:
		progress[current_index].tournament_victories += 1

	func record_defeat() -> void:
		progress[current_index].tournament_defeats += 1
