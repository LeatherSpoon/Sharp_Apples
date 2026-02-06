/**
 * Combat themes, mastery, and damage formulas.
 *
 * Four themes cycle: Unarmed → Armed → Ranged → Energy
 * Only one theme active at a time. Controlling variables benefit all.
 */

import {
  type ControllingVariables,
  type ThemeBonusKey,
  variableScaling,
} from "./variables.js";

// ---------------------------------------------------------------------------
// Theme definitions
// ---------------------------------------------------------------------------

export enum CombatTheme {
  Unarmed = "unarmed",
  Armed = "armed",
  Ranged = "ranged",
  Energy = "energy",
}

/** The fixed cycling order of combat themes. */
export const THEME_ORDER: readonly CombatTheme[] = [
  CombatTheme.Unarmed,
  CombatTheme.Armed,
  CombatTheme.Ranged,
  CombatTheme.Energy,
];

/** Get the next theme in the cycle after a tournament defeat. */
export function nextThemeInCycle(current: CombatTheme): CombatTheme {
  const idx = THEME_ORDER.indexOf(current);
  return THEME_ORDER[(idx + 1) % THEME_ORDER.length];
}

/** Which variable-effect key to use for each theme's damage scaling. */
const THEME_VARIABLE_KEY: Record<CombatTheme, ThemeBonusKey> = {
  [CombatTheme.Unarmed]: "unarmedDamage",
  [CombatTheme.Armed]: "armedDamage",
  [CombatTheme.Ranged]: "rangedBonus",
  [CombatTheme.Energy]: "energyBonus",
};

export interface ThemeDefinition {
  theme: CombatTheme;
  /** Primary scaling variables (with approximate weight shown in docs). */
  primaryScaling: { variable: string; weight: number }[];
  baseAttackSpeed: number;
  unlockRequirement: string;
}

export const THEME_DEFINITIONS: Record<CombatTheme, ThemeDefinition> = {
  [CombatTheme.Unarmed]: {
    theme: CombatTheme.Unarmed,
    primaryScaling: [
      { variable: "strength", weight: 0.7 },
      { variable: "endurance", weight: 0.3 },
    ],
    baseAttackSpeed: 0.5,
    unlockRequirement: "Default (starting theme)",
  },
  [CombatTheme.Armed]: {
    theme: CombatTheme.Armed,
    primaryScaling: [
      { variable: "strength", weight: 0.5 },
      { variable: "dexterity", weight: 0.5 },
    ],
    baseAttackSpeed: 0.8,
    unlockRequirement: "Unarmed Mastery Level 10",
  },
  [CombatTheme.Ranged]: {
    theme: CombatTheme.Ranged,
    primaryScaling: [
      { variable: "dexterity", weight: 0.6 },
      { variable: "focus", weight: 0.4 },
    ],
    baseAttackSpeed: 1.2,
    unlockRequirement: "Armed Mastery Level 10",
  },
  [CombatTheme.Energy]: {
    theme: CombatTheme.Energy,
    primaryScaling: [
      { variable: "focus", weight: 0.6 },
      { variable: "endurance", weight: 0.4 },
    ],
    baseAttackSpeed: 1.0,
    unlockRequirement: "Ranged Mastery Level 10",
  },
};

// ---------------------------------------------------------------------------
// Mastery
// ---------------------------------------------------------------------------

export const MAX_MASTERY_LEVEL = 100;

/**
 * XP required to reach a given mastery level.
 * Formula: 100 × (level ^ 1.5)
 */
export function masteryXPRequired(level: number): number {
  if (level <= 0) return 0;
  return Math.floor(100 * Math.pow(level, 1.5));
}

export interface ThemeMastery {
  level: number;
  xp: number;
}

export type MasteryState = Record<CombatTheme, ThemeMastery>;

export function createMasteryState(): MasteryState {
  return {
    [CombatTheme.Unarmed]: { level: 0, xp: 0 },
    [CombatTheme.Armed]: { level: 0, xp: 0 },
    [CombatTheme.Ranged]: { level: 0, xp: 0 },
    [CombatTheme.Energy]: { level: 0, xp: 0 },
  };
}

/**
 * Award mastery XP to a theme and level up as needed.
 * Returns the number of levels gained.
 */
export function awardMasteryXP(
  mastery: MasteryState,
  theme: CombatTheme,
  xp: number,
): number {
  if (xp <= 0) return 0;
  const entry = mastery[theme];
  entry.xp += xp;

  let levelsGained = 0;
  while (entry.level < MAX_MASTERY_LEVEL) {
    const required = masteryXPRequired(entry.level + 1);
    if (entry.xp < required) break;
    entry.xp -= required;
    entry.level++;
    levelsGained++;
  }

  // Clamp XP if already at max level
  if (entry.level >= MAX_MASTERY_LEVEL) {
    entry.xp = 0;
  }

  return levelsGained;
}

/** Check if a combat theme is unlocked based on mastery levels. */
export function isThemeUnlocked(
  mastery: MasteryState,
  theme: CombatTheme,
): boolean {
  switch (theme) {
    case CombatTheme.Unarmed:
      return true;
    case CombatTheme.Armed:
      return mastery[CombatTheme.Unarmed].level >= 10;
    case CombatTheme.Ranged:
      return mastery[CombatTheme.Armed].level >= 10;
    case CombatTheme.Energy:
      return mastery[CombatTheme.Ranged].level >= 10;
  }
}

/**
 * Cross-theme mastery bonus.
 * Themes at mastery 50+ grant cumulative damage bonus to all themes.
 */
export function crossThemeMasteryBonus(mastery: MasteryState): number {
  const countAt50Plus = Object.values(mastery).filter(
    (m) => m.level >= 50,
  ).length;
  switch (countAt50Plus) {
    case 2:
      return 0.05;
    case 3:
      return 0.1;
    case 4:
      return 0.2;
    default:
      return 0;
  }
}

// ---------------------------------------------------------------------------
// Combat damage formula
// ---------------------------------------------------------------------------

/**
 * Base damage multiplier from theme (used as ThemeMultiplier in formula).
 * Each theme has a baseline multiplier of 1.0; the real differentiation
 * comes from attack speed and mechanics. This is here for future tuning.
 */
const BASE_THEME_MULTIPLIER: Record<CombatTheme, number> = {
  [CombatTheme.Unarmed]: 1.0,
  [CombatTheme.Armed]: 1.0,
  [CombatTheme.Ranged]: 1.0,
  [CombatTheme.Energy]: 1.0,
};

export interface DamageParams {
  baseDamage: number;
  powerLevel: number;
  theme: CombatTheme;
  variables: ControllingVariables;
  mastery: MasteryState;
}

/**
 * Calculate combat damage.
 *
 * Formula: BaseDamage × (1 + PowerLevel/100) × ThemeMultiplier × (1 + VariableScaling) × (1 + CrossThemeBonus)
 */
export function calculateDamage(params: DamageParams): number {
  const { baseDamage, powerLevel, theme, variables, mastery } = params;
  const powerMult = 1 + powerLevel / 100;
  const themeMult = BASE_THEME_MULTIPLIER[theme];
  const varScale = 1 + variableScaling(variables, THEME_VARIABLE_KEY[theme]);
  const crossBonus = 1 + crossThemeMasteryBonus(mastery);

  return baseDamage * powerMult * themeMult * varScale * crossBonus;
}

// ---------------------------------------------------------------------------
// Tournament difficulty
// ---------------------------------------------------------------------------

/**
 * Calculate opponent power in an infinite tournament.
 *
 * Formula: BasePower × (1.05 ^ VictoryCount) × EnvironmentTier
 */
export function tournamentOpponentPower(
  basePower: number,
  victoryCount: number,
  environmentTier: number,
): number {
  return basePower * Math.pow(1.05, victoryCount) * environmentTier;
}

/**
 * Estimate whether the player is expected to lose at this point.
 *
 * From design doc: expected loss when OpponentPower > PlayerPower × 1.2
 */
export function isExpectedLoss(
  opponentPower: number,
  playerPower: number,
): boolean {
  return opponentPower > playerPower * 1.2;
}
