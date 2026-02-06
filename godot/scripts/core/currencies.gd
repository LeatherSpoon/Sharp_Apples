class_name Currencies
## Core currencies: Power Level (NGU Idle-style), Pedometer, Gold.
##
## Power Level has two layers:
##   - current: resets to 1 each master reset, spendable on iterative upgrades
##   - permanent: persists forever, gained from permanent upgrades
##   - effective PL = permanent + current
##
## Pedometer: spend-all-or-nothing, resets to 0 on spend.
## Gold: active-only, no passive generation.


# ---- Power Level ----

class PowerLevelState:
	var current: float = 1.0
	var permanent: float = 0.0
	var lifetime_earned: float = 0.0
	var lifetime_spent: float = 0.0
	var times_reset: int = 0

	func effective() -> float:
		return permanent + current

	func earn(amount: float) -> void:
		if amount > 0:
			current += amount
			lifetime_earned += amount

	func spend(cost: float) -> bool:
		if cost <= 0 or current < cost:
			return false
		current -= cost
		lifetime_spent += cost
		return true

	func buy_permanent_upgrade(cost: float, perm_gain: float) -> bool:
		if not spend(cost):
			return false
		permanent += perm_gain
		return true

	func reset() -> float:
		var lost := current
		times_reset += 1
		current = 1.0
		return lost

	func add_permanent(amount: float) -> void:
		if amount > 0:
			permanent += amount


# ---- Pedometer ----

const PEDOMETER_MILESTONES: Array[int] = [
	100, 500, 1000, 5000, 10000, 50000, 100000,
]

class PedometerState:
	var steps: float = 0.0
	var total_steps_spent: float = 0.0
	var times_spent: int = 0

	func add_steps(amount: float) -> void:
		if amount > 0:
			steps += amount

	## Speed bonus = log10(steps) * 10. Returns 0 if steps < 10.
	func speed_bonus() -> float:
		if steps < 10:
			return 0.0
		return log(steps) / log(10.0) * 10.0

	## Spend all steps. Returns dict { steps_spent, speed_bonus_percent }.
	func spend() -> Dictionary:
		if steps <= 0:
			return { "steps_spent": 0.0, "speed_bonus_percent": 0.0 }
		var bonus := speed_bonus()
		var spent := steps
		total_steps_spent += spent
		times_spent += 1
		steps = 0.0
		return { "steps_spent": spent, "speed_bonus_percent": bonus }

	func current_milestone() -> int:
		for i in range(Currencies.PEDOMETER_MILESTONES.size() - 1, -1, -1):
			if steps >= Currencies.PEDOMETER_MILESTONES[i]:
				return Currencies.PEDOMETER_MILESTONES[i]
		return 0


# ---- Gold ----

class GoldState:
	var balance: float = 0.0
	var lifetime_earned: float = 0.0
	var lifetime_spent: float = 0.0

	func earn(amount: float) -> void:
		if amount > 0:
			balance += amount
			lifetime_earned += amount

	func spend(cost: float) -> bool:
		if cost <= 0 or balance < cost:
			return false
		balance -= cost
		lifetime_spent += cost
		return true
