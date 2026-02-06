/**
 * Core currencies for MyRPG.
 *
 * Power Level - NGU Idle-style "big number": earnable, spendable on upgrades,
 *   resets to 1 with each new master. Has permanent + iterative layers.
 * Pedometer Count - lifetime steps, spend-all-or-nothing for speed upgrades
 * Gold - active economy currency (no passive generation)
 */

// ---------------------------------------------------------------------------
// Power Level (NGU Idle-style)
// ---------------------------------------------------------------------------

/**
 * Power Level has two layers, inspired by NGU Idle's rebirth model:
 *
 *   current    – The working number. Starts at 1 with each new master.
 *                Increases via training/combat. Can be SPENT on upgrades.
 *   permanent  – Baseline that persists across master resets. Accumulated
 *                by purchasing permanent upgrades with current PL.
 *
 *   effective  = permanent + current  (used in combat formulas)
 *
 * Iterative upgrades cost current PL and are lost on master reset.
 * Permanent upgrades cost current PL but add to permanent PL (at a rate).
 * On master reset: current → 1, iterative upgrades wiped, permanent stays.
 */
export interface PowerLevelState {
  /** Working PL for this master cycle. Starts at 1, goes up and down. */
  current: number;
  /** Permanent PL baseline. Persists across master resets. */
  permanent: number;
  /** Total PL earned across all time (stat tracking, achievements). */
  lifetimeEarned: number;
  /** Total PL spent on all upgrades across all time. */
  lifetimeSpent: number;
  /** Number of master resets performed. */
  timesReset: number;
}

export function createPowerLevel(): PowerLevelState {
  return {
    current: 1,
    permanent: 0,
    lifetimeEarned: 0,
    lifetimeSpent: 0,
    timesReset: 0,
  };
}

/** Effective Power Level used in all combat/progression formulas. */
export function effectivePowerLevel(state: PowerLevelState): number {
  return state.permanent + state.current;
}

/**
 * Earn current PL from training, combat victories, tournament milestones, etc.
 */
export function earnPowerLevel(state: PowerLevelState, amount: number): void {
  if (amount > 0) {
    state.current += amount;
    state.lifetimeEarned += amount;
  }
}

/**
 * Spend current PL on an iterative upgrade (lost on master reset).
 * Returns true if the player had enough, false otherwise.
 */
export function spendPowerLevel(state: PowerLevelState, cost: number): boolean {
  if (cost <= 0) return true;
  if (state.current < cost) return false;
  state.current -= cost;
  state.lifetimeSpent += cost;
  return true;
}

/**
 * Spend current PL to buy a permanent upgrade.
 *
 * @param cost      Amount of current PL to spend.
 * @param permGain  Amount added to permanent PL (can differ from cost for
 *                  balance — e.g. spend 100 current, gain 10 permanent).
 * @returns true if successful, false if insufficient current PL.
 */
export function buyPermanentUpgrade(
  state: PowerLevelState,
  cost: number,
  permGain: number,
): boolean {
  if (cost <= 0) return true;
  if (state.current < cost) return false;
  state.current -= cost;
  state.lifetimeSpent += cost;
  state.permanent += permGain;
  return true;
}

/**
 * Reset current PL to 1 (new master transition).
 * Permanent PL is preserved. Returns the current PL that was lost.
 */
export function resetPowerLevel(state: PowerLevelState): number {
  const lost = state.current;
  state.current = 1;
  state.timesReset++;
  return lost;
}

/**
 * Add directly to permanent PL (for achievement rewards, pedometer bonuses, etc.).
 */
export function addPermanentPowerLevel(
  state: PowerLevelState,
  amount: number,
): void {
  if (amount > 0) {
    state.permanent += amount;
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
