/**
 * Controlling Variables — stats that drive combat theme scaling,
 * trainable through laborious activities or automated by managers.
 *
 * Core 4 (original):
 *   Strength   (Mining, Lumberjacking) → Unarmed/Armed damage
 *   Dexterity  (Obstacle Courses)      → Ranged accuracy, Armed speed
 *   Focus      (Meditation)            → Energy capacity, Ranged range
 *   Endurance  (Distance Running)      → HP, all-theme defense
 *
 * Extended:
 *   Luck       (Fishing)              → Crit chance, loot quality, rare drops
 */

export enum VariableKind {
  Strength = "strength",
  Dexterity = "dexterity",
  Focus = "focus",
  Endurance = "endurance",
  Luck = "luck",
}

export enum TrainingActivity {
  Mining = "mining",
  ObstacleCourse = "obstacle_course",
  Meditation = "meditation",
  DistanceRunning = "distance_running",
  Lumberjacking = "lumberjacking",
  Fishing = "fishing",
  Farming = "farming",
}

/**
 * Maps each activity to the variable it primarily trains.
 * Note: multiple activities can train the same variable (e.g. Mining
 * and Lumberjacking both train Strength).
 */
export const ACTIVITY_VARIABLE_MAP: Record<TrainingActivity, VariableKind> = {
  [TrainingActivity.Mining]: VariableKind.Strength,
  [TrainingActivity.Lumberjacking]: VariableKind.Strength,
  [TrainingActivity.ObstacleCourse]: VariableKind.Dexterity,
  [TrainingActivity.Meditation]: VariableKind.Focus,
  [TrainingActivity.DistanceRunning]: VariableKind.Endurance,
  [TrainingActivity.Fishing]: VariableKind.Luck,
  [TrainingActivity.Farming]: VariableKind.Endurance,
};

/** @deprecated Use ACTIVITY_VARIABLE_MAP instead. Kept for backward compat. */
export const VARIABLE_TRAINING_MAP: Record<VariableKind, TrainingActivity> = {
  [VariableKind.Strength]: TrainingActivity.Mining,
  [VariableKind.Dexterity]: TrainingActivity.ObstacleCourse,
  [VariableKind.Focus]: TrainingActivity.Meditation,
  [VariableKind.Endurance]: TrainingActivity.DistanceRunning,
  [VariableKind.Luck]: TrainingActivity.Fishing,
};

/** Active training gains per hour at each effort level. */
export enum TrainingIntensity {
  Casual = 10,
  Focused = 25,
  Deep = 50,
}

export interface ControllingVariables {
  [VariableKind.Strength]: number;
  [VariableKind.Dexterity]: number;
  [VariableKind.Focus]: number;
  [VariableKind.Endurance]: number;
  [VariableKind.Luck]: number;
}

export function createControllingVariables(): ControllingVariables {
  return {
    [VariableKind.Strength]: 0,
    [VariableKind.Dexterity]: 0,
    [VariableKind.Focus]: 0,
    [VariableKind.Endurance]: 0,
    [VariableKind.Luck]: 0,
  };
}

export function trainVariable(
  vars: ControllingVariables,
  kind: VariableKind,
  amount: number,
): void {
  if (amount > 0) {
    vars[kind] += amount;
  }
}

// ---------------------------------------------------------------------------
// Per-point effects (from design doc tables)
// ---------------------------------------------------------------------------

export interface VariableEffects {
  /** Unarmed damage bonus per point */
  unarmedDamage: number;
  /** Armed damage bonus per point */
  armedDamage: number;
  /** Ranged damage/accuracy bonus per point */
  rangedBonus: number;
  /** Energy damage/capacity bonus per point */
  energyBonus: number;
  /** General bonus description */
  generalBonus: string;
  /** General bonus per point */
  generalValue: number;
}

export const VARIABLE_EFFECTS: Record<VariableKind, VariableEffects> = {
  [VariableKind.Strength]: {
    unarmedDamage: 0.02,
    armedDamage: 0.02,
    rangedBonus: 0.005,
    energyBonus: 0.005,
    generalBonus: "carry capacity",
    generalValue: 1,
  },
  [VariableKind.Dexterity]: {
    unarmedDamage: 0.005,
    armedDamage: 0.005,
    rangedBonus: 0.01,
    energyBonus: 0.005,
    generalBonus: "movement efficiency",
    generalValue: 0.005,
  },
  [VariableKind.Focus]: {
    unarmedDamage: 0.005,
    armedDamage: 0.005,
    rangedBonus: 0.005,
    energyBonus: 0.01,
    generalBonus: "training efficiency",
    generalValue: 0.01,
  },
  [VariableKind.Endurance]: {
    unarmedDamage: 0.005,
    armedDamage: 0.005,
    rangedBonus: 0.005,
    energyBonus: 0.01,
    generalBonus: "max HP / stamina regen",
    generalValue: 1,
  },
  [VariableKind.Luck]: {
    unarmedDamage: 0.002,
    armedDamage: 0.002,
    rangedBonus: 0.002,
    energyBonus: 0.002,
    generalBonus: "crit chance / loot quality",
    generalValue: 0.005,
  },
};

/**
 * Compute the total variable-scaling multiplier for a given combat theme.
 *
 * From the design doc appendix:
 *   VariableScaling = (PrimaryVar × 0.02) + (SecondaryVar × 0.01)
 *
 * The per-theme primary/secondary relationships are captured in the
 * VARIABLE_EFFECTS table. This helper aggregates across all four variables.
 */
export type ThemeBonusKey =
  | "unarmedDamage"
  | "armedDamage"
  | "rangedBonus"
  | "energyBonus";

export function variableScaling(
  vars: ControllingVariables,
  themeKey: ThemeBonusKey,
): number {
  let total = 0;
  for (const kind of Object.values(VariableKind)) {
    total += vars[kind] * VARIABLE_EFFECTS[kind][themeKey];
  }
  return total;
}

/**
 * Max HP derived from Endurance.
 * Base HP (100) + 1 per Endurance point.
 */
export const BASE_HP = 100;

export function maxHP(endurance: number): number {
  return BASE_HP + endurance;
}

/**
 * Energy pool size derived from Focus.
 * Formula: 100 + (Focus × 5)
 */
export const BASE_ENERGY_POOL = 100;

export function energyPoolSize(focus: number): number {
  return BASE_ENERGY_POOL + focus * 5;
}

/**
 * Energy regen rate (per second) derived from Focus.
 * Formula: 5 + (Focus × 0.5)
 */
export const BASE_ENERGY_REGEN = 5;

export function energyRegenRate(focus: number): number {
  return BASE_ENERGY_REGEN + focus * 0.5;
}

/**
 * Crit chance derived from Luck.
 * Base 5% + 0.5% per Luck point, capped at 50%.
 */
export const BASE_CRIT_CHANCE = 0.05;
export const CRIT_CHANCE_PER_LUCK = 0.005;
export const MAX_CRIT_CHANCE = 0.5;

export function critChance(luck: number): number {
  return Math.min(BASE_CRIT_CHANCE + luck * CRIT_CHANCE_PER_LUCK, MAX_CRIT_CHANCE);
}

/**
 * Loot quality multiplier derived from Luck.
 * Formula: 1.0 + (Luck × 0.01)  — each point gives +1% better drops.
 */
export function lootQualityMultiplier(luck: number): number {
  return 1.0 + luck * 0.01;
}
