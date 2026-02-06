/**
 * Controlling Variables — the four stats that drive combat theme scaling
 * and are trainable through active activities or automated by managers.
 *
 * Strength   (Mining)           → Unarmed/Armed damage
 * Dexterity  (Obstacle Courses) → Ranged accuracy, Armed speed
 * Focus      (Meditation)       → Energy capacity, Ranged range
 * Endurance  (Distance Running) → HP, all-theme defense
 */

export enum VariableKind {
  Strength = "strength",
  Dexterity = "dexterity",
  Focus = "focus",
  Endurance = "endurance",
}

export enum TrainingActivity {
  Mining = "mining",
  ObstacleCourse = "obstacle_course",
  Meditation = "meditation",
  DistanceRunning = "distance_running",
}

/** Maps each controlling variable to the activity that trains it. */
export const VARIABLE_TRAINING_MAP: Record<VariableKind, TrainingActivity> = {
  [VariableKind.Strength]: TrainingActivity.Mining,
  [VariableKind.Dexterity]: TrainingActivity.ObstacleCourse,
  [VariableKind.Focus]: TrainingActivity.Meditation,
  [VariableKind.Endurance]: TrainingActivity.DistanceRunning,
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
}

export function createControllingVariables(): ControllingVariables {
  return {
    [VariableKind.Strength]: 0,
    [VariableKind.Dexterity]: 0,
    [VariableKind.Focus]: 0,
    [VariableKind.Endurance]: 0,
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
