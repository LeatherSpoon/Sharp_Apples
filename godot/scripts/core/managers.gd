class_name Managers
## Manager & Automation system.
##
## Tier 1: Task Managers   — 50% base, diminishing returns on stacking
## Tier 2: Department Mgrs — +25% to managed Task Managers
## Tier 3: VP of Training  — +50% to all, auto-hire
## Tier 4: CEO             — prestige multiplier
## Efficiency cap: 100% of active rate (automation never beats active play)

enum TaskManagerType {
	MINING_FOREMAN,
	COURSE_INSTRUCTOR,
	MEDITATION_GUIDE,
	RUNNING_COACH,
	LUMBERJACK_BOSS,
	FISHING_CAPTAIN,
	FARM_OVERSEER,
}

enum Category {
	PHYSICAL,
	MENTAL,
	GATHERING,
}

const TASK_MANAGER_ACTIVITY: Dictionary = {
	TaskManagerType.MINING_FOREMAN: Variables.TrainingActivity.MINING,
	TaskManagerType.COURSE_INSTRUCTOR: Variables.TrainingActivity.OBSTACLE_COURSE,
	TaskManagerType.MEDITATION_GUIDE: Variables.TrainingActivity.MEDITATION,
	TaskManagerType.RUNNING_COACH: Variables.TrainingActivity.DISTANCE_RUNNING,
	TaskManagerType.LUMBERJACK_BOSS: Variables.TrainingActivity.LUMBERJACKING,
	TaskManagerType.FISHING_CAPTAIN: Variables.TrainingActivity.FISHING,
	TaskManagerType.FARM_OVERSEER: Variables.TrainingActivity.FARMING,
}

const TASK_MANAGER_CATEGORY: Dictionary = {
	TaskManagerType.MINING_FOREMAN: Category.PHYSICAL,
	TaskManagerType.COURSE_INSTRUCTOR: Category.MENTAL,
	TaskManagerType.MEDITATION_GUIDE: Category.MENTAL,
	TaskManagerType.RUNNING_COACH: Category.PHYSICAL,
	TaskManagerType.LUMBERJACK_BOSS: Category.PHYSICAL,
	TaskManagerType.FISHING_CAPTAIN: Category.GATHERING,
	TaskManagerType.FARM_OVERSEER: Category.GATHERING,
}

const TASK_MANAGER_BASE_COST: int = 1_000
const DEPARTMENT_MANAGER_COST: int = 10_000
const VP_COST: int = 100_000
const CEO_COST: int = 1_000_000
const CASUAL_ACTIVE_RATE_PER_HOUR: float = 10.0


# ---- Cost calculations ----

static func task_manager_cost(owned_count: int) -> int:
	return TASK_MANAGER_BASE_COST * int(pow(2, owned_count))


static func total_task_manager_investment(count: int) -> int:
	if count <= 0:
		return 0
	return TASK_MANAGER_BASE_COST * (int(pow(2, count)) - 1)


# ---- Efficiency ----

## Diminishing returns: 1 - 0.5^count
static func stack_efficiency(count: int) -> float:
	if count <= 0:
		return 0.0
	return 1.0 - pow(0.5, count)


# ---- State ----

class State:
	var task_managers: Dictionary = {}
	var physical_director: bool = false
	var mental_director: bool = false
	var gathering_director: bool = false
	var vp_of_training: bool = false
	var vp_auto_hire_enabled: bool = false
	var ceo: bool = false
	var prestige_level: int = 0

	func _init() -> void:
		for type_key in TaskManagerType.values():
			task_managers[type_key] = 0

	func can_unlock_department(category: int) -> bool:
		var count := 0
		for type_key in task_managers:
			if TASK_MANAGER_CATEGORY.get(type_key) == category:
				count += task_managers[type_key]
		return count >= 2

	func can_unlock_vp() -> bool:
		return physical_director and mental_director and gathering_director

	func can_unlock_ceo(has_completed_theme_cycle: bool) -> bool:
		return vp_of_training and has_completed_theme_cycle

	func automation_efficiency(type_key: int) -> float:
		var count: int = task_managers.get(type_key, 0)
		if count == 0:
			return 0.0
		var base := Managers.stack_efficiency(count)
		var category: int = TASK_MANAGER_CATEGORY[type_key]
		var has_dept := false
		match category:
			Category.PHYSICAL: has_dept = physical_director
			Category.MENTAL: has_dept = mental_director
			Category.GATHERING: has_dept = gathering_director
		var dept_bonus := 1.25 if has_dept else 1.0
		var exec_bonus := 1.5 if vp_of_training else 1.0
		var prestige_mult := 1.0 + 0.1 * prestige_level
		return minf(base * dept_bonus * exec_bonus * prestige_mult, 1.0)

	func passive_gains_per_hour(type_key: int) -> float:
		return automation_efficiency(type_key) * CASUAL_ACTIVE_RATE_PER_HOUR

	func perform_prestige() -> Dictionary:
		prestige_level += 1
		var mult := 1.0 + 0.1 * prestige_level
		for type_key in task_managers:
			task_managers[type_key] = 0
		physical_director = false
		mental_director = false
		gathering_director = false
		vp_of_training = false
		vp_auto_hire_enabled = false
		ceo = false
		return { "new_prestige_level": prestige_level, "multiplier": mult }
