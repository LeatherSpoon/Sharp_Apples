class_name GameEnvironment
## Environment definitions and progression.
##
## Each environment defines visual theming, combat style, and tier.
## Designed to scale to 50+ unique worlds via data-driven definitions.
## Players can travel between unlocked environments.

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
		"combat_theme": Combat.CombatTheme.UNARMED,
		"description": "A tranquil woodland clearing where the first master teaches bare-handed combat.",
		"ground_color": Color(0.18, 0.55, 0.22),
		"path_color": Color(0.55, 0.4, 0.25),
		"has_pond": true,
		"has_dojo": true,
		"unlock_tier": 0,
	},
	{
		"id": "deep_mine",
		"name": "Deep Mine",
		"tier": 2,
		"combat_theme": Combat.CombatTheme.UNARMED,
		"description": "Dark tunnels carved into the mountain. Fists meet stone and shadow.",
		"ground_color": Color(0.15, 0.13, 0.12),
		"path_color": Color(0.28, 0.24, 0.2),
		"has_pond": false,
		"has_dojo": false,
		"unlock_tier": 0,
	},
	{
		"id": "iron_fortress",
		"name": "Iron Fortress",
		"tier": 3,
		"combat_theme": Combat.CombatTheme.ARMED,
		"description": "A towering fortress of dark iron, where bladed weapons define survival.",
		"ground_color": Color(0.25, 0.22, 0.22),
		"path_color": Color(0.4, 0.35, 0.3),
		"has_pond": false,
		"has_dojo": true,
		"unlock_tier": 2,
	},
	{
		"id": "wind_valley",
		"name": "Wind Valley",
		"tier": 4,
		"combat_theme": Combat.CombatTheme.RANGED,
		"description": "Sweeping canyons with treacherous winds — perfect for ranged mastery.",
		"ground_color": Color(0.6, 0.52, 0.35),
		"path_color": Color(0.5, 0.42, 0.28),
		"has_pond": false,
		"has_dojo": false,
		"unlock_tier": 3,
	},
	{
		"id": "crystal_spire",
		"name": "Crystal Spire",
		"tier": 5,
		"combat_theme": Combat.CombatTheme.ENERGY,
		"description": "A crystalline tower pulsing with raw energy, where power techniques reign.",
		"ground_color": Color(0.22, 0.2, 0.35),
		"path_color": Color(0.35, 0.3, 0.5),
		"has_pond": true,
		"has_dojo": true,
		"unlock_tier": 4,
	},
	{
		"id": "desert_temple",
		"name": "Desert Temple",
		"tier": 6,
		"combat_theme": Combat.CombatTheme.UNARMED,
		"description": "An ancient temple buried in sand. The cycle begins anew at greater power.",
		"ground_color": Color(0.7, 0.6, 0.4),
		"path_color": Color(0.55, 0.45, 0.3),
		"has_pond": false,
		"has_dojo": true,
		"unlock_tier": 5,
	},
]


class EnvironmentProgress:
	var tournament_victories: int = 0
	var tournament_defeats: int = 0
	var phase: int = Phase.TRAINING


class ProgressionState:
	var current_index: int = 0
	var progress: Array[EnvironmentProgress] = []
	var highest_tier_reached: int = 1  # tracks which worlds are unlocked

	func _init() -> void:
		for i in ENVIRONMENTS.size():
			progress.append(EnvironmentProgress.new())

	func current_environment() -> Dictionary:
		return ENVIRONMENTS[current_index]

	func current_environment_name() -> String:
		return ENVIRONMENTS[current_index]["name"]

	func current_combat_theme() -> int:
		return ENVIRONMENTS[current_index]["combat_theme"]

	func is_unlocked(env_index: int) -> bool:
		if env_index < 0 or env_index >= ENVIRONMENTS.size():
			return false
		var req: int = ENVIRONMENTS[env_index]["unlock_tier"]
		return highest_tier_reached >= req

	func travel_to(env_index: int) -> bool:
		if not is_unlocked(env_index):
			return false
		current_index = env_index
		return true

	func advance() -> Dictionary:
		if current_index >= ENVIRONMENTS.size() - 1:
			return {}  # No more authored environments
		var env_tier: int = ENVIRONMENTS[current_index]["tier"]
		if env_tier > highest_tier_reached:
			highest_tier_reached = env_tier
		current_index += 1
		var new_tier: int = ENVIRONMENTS[current_index]["tier"]
		if new_tier > highest_tier_reached:
			highest_tier_reached = new_tier
		return ENVIRONMENTS[current_index]

	func record_victory() -> void:
		progress[current_index].tournament_victories += 1
		var env_tier: int = ENVIRONMENTS[current_index]["tier"]
		if env_tier > highest_tier_reached:
			highest_tier_reached = env_tier

	func record_defeat() -> void:
		progress[current_index].tournament_defeats += 1
