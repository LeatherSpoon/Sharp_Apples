/**
 * Core currencies for MyRPG.
 *
 * Power Level - the main "big number" for combat strength (always increasing, no cap)
 * Pedometer Count - lifetime steps, spend-all-or-nothing for speed upgrades
 * Gold - active economy currency (no passive generation)
 */

// ---------------------------------------------------------------------------
// Power Level
// ---------------------------------------------------------------------------

export interface PowerLevelState {
  /** Current power level value. Starts at 1, never decreases. */
  value: number;
}

export function createPowerLevel(): PowerLevelState {
  return { value: 1 };
}

/**
 * Increase power level by `amount`. Negative values are ignored so the
 * number can only go up.
 */
export function addPowerLevel(state: PowerLevelState, amount: number): void {
  if (amount > 0) {
    state.value += amount;
  }
}

// ---------------------------------------------------------------------------
// Pedometer
// ---------------------------------------------------------------------------

/** Milestones that gate different reward tiers. */
export const PEDOMETER_MILESTONES = [
  { steps: 1_000, label: "Minor speed upgrade" },
  { steps: 10_000, label: "Medium speed upgrade" },
  { steps: 100_000, label: "Major speed upgrade" },
  { steps: 1_000_000, label: "Speed tile unlock" },
  { steps: 10_000_000, label: "Achievement-based Power Level bonuses" },
] as const;

export interface PedometerState {
  /** Current accumulated step count (resets to 0 on spend). */
  count: number;
  /** Lifetime total of all steps ever taken (never resets). */
  lifetimeSteps: number;
  /** How many times the player has spent (reset) their pedometer. */
  timesSpent: number;
}

export function createPedometer(): PedometerState {
  return { count: 0, lifetimeSteps: 0, timesSpent: 0 };
}

/** Add steps from movement. */
export function addSteps(state: PedometerState, steps: number): void {
  if (steps > 0) {
    state.count += steps;
    state.lifetimeSteps += steps;
  }
}

/**
 * Calculate the speed bonus percentage that would be granted if the player
 * spent their current pedometer count right now.
 *
 * Formula from design doc: `log10(StepsSpent) × 10`
 */
export function pedometerSpeedBonus(stepsSpent: number): number {
  if (stepsSpent <= 0) return 0;
  return Math.log10(stepsSpent) * 10;
}

/** The highest milestone reached for a given step count. */
export function currentMilestone(
  steps: number,
): (typeof PEDOMETER_MILESTONES)[number] | null {
  let best: (typeof PEDOMETER_MILESTONES)[number] | null = null;
  for (const m of PEDOMETER_MILESTONES) {
    if (steps >= m.steps) best = m;
  }
  return best;
}

export interface PedometerSpendResult {
  stepsSpent: number;
  speedBonusPercent: number;
}

/**
 * Spend **all** accumulated steps (full-reset style).
 * Returns details about what was spent and the resulting speed bonus.
 */
export function spendPedometer(state: PedometerState): PedometerSpendResult {
  const stepsSpent = state.count;
  const speedBonusPercent = pedometerSpeedBonus(stepsSpent);
  state.count = 0;
  state.timesSpent++;
  return { stepsSpent, speedBonusPercent };
}

// ---------------------------------------------------------------------------
// Gold
// ---------------------------------------------------------------------------

export interface GoldState {
  /** Current gold the player is holding. */
  amount: number;
  /** Lifetime gold earned (for stats / achievement tracking). */
  lifetimeEarned: number;
}

export function createGold(): GoldState {
  return { amount: 0, lifetimeEarned: 0 };
}

/** Earn gold from loot sales, tournament rewards, etc. */
export function earnGold(state: GoldState, amount: number): void {
  if (amount > 0) {
    state.amount += amount;
    state.lifetimeEarned += amount;
  }
}

/**
 * Spend gold. Returns `true` if the player had enough and gold was deducted,
 * `false` otherwise (balance unchanged).
 */
export function spendGold(state: GoldState, cost: number): boolean {
  if (cost <= 0) return true;
  if (state.amount < cost) return false;
  state.amount -= cost;
  return true;
}
