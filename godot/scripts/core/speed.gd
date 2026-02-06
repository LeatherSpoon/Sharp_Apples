class_name Speed
## Speed & Movement system.
##
## Base speed = 100. Pedometer upgrades add %, capped at +500%.
## Tiles provide additional uncapped bonuses.
## Environment tiers have minimum speed requirements.

const BASE_SPEED: float = 100.0
const PEDOMETER_SPEED_CAP_PERCENT: float = 500.0

enum TileType {
	GRASS,
	DIRT_PATH,
	STONE_ROAD,
	ENCHANTED_PATH,
}

const TILE_DEFINITIONS: Dictionary = {
	TileType.GRASS: { "name": "Grass", "speed_mult": 1.0 },
	TileType.DIRT_PATH: { "name": "Dirt Path", "speed_mult": 1.15 },
	TileType.STONE_ROAD: { "name": "Stone Road", "speed_mult": 1.30 },
	TileType.ENCHANTED_PATH: { "name": "Enchanted Path", "speed_mult": 1.50 },
}

const ENVIRONMENT_SPEED_REQUIREMENTS: Array[float] = [
	0.0,    # Tier 1 — no requirement
	150.0,  # Tier 2
	250.0,  # Tier 3
	400.0,  # Tier 4
	600.0,  # Tier 5
]

enum Status {
	LOCKED,
	SLOW,
	NORMAL,
	FAST,
}


class State:
	var pedometer_bonus_percent: float = 0.0
	var tile_bonus_percent: float = 0.0

	func effective_speed() -> float:
		return BASE_SPEED * (1.0 + (pedometer_bonus_percent + tile_bonus_percent) / 100.0)

	func apply_pedometer_upgrade(bonus: float) -> void:
		pedometer_bonus_percent = minf(
			pedometer_bonus_percent + bonus,
			PEDOMETER_SPEED_CAP_PERCENT,
		)

	func is_pedometer_capped() -> bool:
		return pedometer_bonus_percent >= PEDOMETER_SPEED_CAP_PERCENT


static func minimum_speed_for_tier(tier: int) -> float:
	if tier < 1 or tier > ENVIRONMENT_SPEED_REQUIREMENTS.size():
		return 0.0
	return ENVIRONMENT_SPEED_REQUIREMENTS[tier - 1]


static func speed_status_for_tier(current_speed: float, tier: int) -> int:
	var required := minimum_speed_for_tier(tier)
	if required <= 0:
		return Status.NORMAL
	if current_speed < required * 0.5:
		return Status.LOCKED
	if current_speed < required:
		return Status.SLOW
	if current_speed >= required * 1.5:
		return Status.FAST
	return Status.NORMAL
