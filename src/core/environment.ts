/**
 * Environment / progression structure.
 *
 * Each environment has a themed Master, mob set, boss, and infinite tournament.
 * Progression: Train → Farm → Boss → Tournament → Defeat → New Master/Zone.
 */

import { CombatTheme, THEME_ORDER } from "./combat.js";

// ---------------------------------------------------------------------------
// Environment definitions
// ---------------------------------------------------------------------------

export interface EnvironmentDefinition {
  id: string;
  name: string;
  tier: number;
  masterName: string;
  combatTheme: CombatTheme;
  description: string;
}

/**
 * The initial authored environments. More can be added; the theme cycles
 * through the THEME_ORDER array.
 */
export const ENVIRONMENTS: EnvironmentDefinition[] = [
  {
    id: "forest_dojo",
    name: "Forest Dojo",
    tier: 1,
    masterName: "Master Chen",
    combatTheme: CombatTheme.Unarmed,
    description: "A peaceful forest clearing where training begins. Inspired by Stardew Valley.",
  },
  {
    id: "iron_fortress",
    name: "Iron Fortress",
    tier: 2,
    masterName: "Sir Aldric",
    combatTheme: CombatTheme.Armed,
    description: "A massive fortress of iron and stone. Weapons line every wall.",
  },
  {
    id: "wind_valley",
    name: "Wind Valley",
    tier: 3,
    masterName: "Hawk Eye",
    combatTheme: CombatTheme.Ranged,
    description: "Open valleys swept by endless wind. Precision is everything here.",
  },
  {
    id: "crystal_spire",
    name: "Crystal Spire",
    tier: 4,
    masterName: "Archmage Vera",
    combatTheme: CombatTheme.Energy,
    description: "A towering spire of living crystal that hums with arcane power.",
  },
  {
    id: "desert_temple",
    name: "Desert Temple",
    tier: 5,
    masterName: "Grandmaster Kai",
    combatTheme: CombatTheme.Unarmed,
    description: "An ancient temple hidden in shifting sands. The cycle begins anew.",
  },
];

// ---------------------------------------------------------------------------
// Environment progression state
// ---------------------------------------------------------------------------

export enum EnvironmentPhase {
  Training = "training",
  Farming = "farming",
  Boss = "boss",
  Tournament = "tournament",
}

export interface EnvironmentProgress {
  environmentId: string;
  phase: EnvironmentPhase;
  bossDefeated: boolean;
  tournamentVictories: number;
  /** Whether the player has been defeated in this environment's tournament. */
  tournamentDefeated: boolean;
}

export interface ProgressionState {
  /** Index into ENVIRONMENTS for the current active environment. */
  currentEnvironmentIndex: number;
  /** All environments the player has unlocked (by id). */
  unlockedEnvironments: string[];
  /** Per-environment progress tracking. */
  environmentProgress: Record<string, EnvironmentProgress>;
  /** How many full theme cycles have been completed (for CEO unlock). */
  themeCyclesCompleted: number;
}

export function createProgressionState(): ProgressionState {
  const firstEnv = ENVIRONMENTS[0];
  return {
    currentEnvironmentIndex: 0,
    unlockedEnvironments: [firstEnv.id],
    environmentProgress: {
      [firstEnv.id]: {
        environmentId: firstEnv.id,
        phase: EnvironmentPhase.Training,
        bossDefeated: false,
        tournamentVictories: 0,
        tournamentDefeated: false,
      },
    },
    themeCyclesCompleted: 0,
  };
}

/** Get the current environment definition. */
export function currentEnvironment(state: ProgressionState): EnvironmentDefinition {
  return ENVIRONMENTS[state.currentEnvironmentIndex];
}

/** Get the combat theme for the current environment. */
export function currentCombatTheme(state: ProgressionState): CombatTheme {
  return currentEnvironment(state).combatTheme;
}

/**
 * Advance to the next environment after a tournament defeat.
 * Returns the newly unlocked environment, or null if no more authored
 * environments exist.
 */
export function advanceEnvironment(
  state: ProgressionState,
): EnvironmentDefinition | null {
  const nextIndex = state.currentEnvironmentIndex + 1;
  if (nextIndex >= ENVIRONMENTS.length) return null;

  const nextEnv = ENVIRONMENTS[nextIndex];
  state.currentEnvironmentIndex = nextIndex;

  if (!state.unlockedEnvironments.includes(nextEnv.id)) {
    state.unlockedEnvironments.push(nextEnv.id);
  }

  if (!state.environmentProgress[nextEnv.id]) {
    state.environmentProgress[nextEnv.id] = {
      environmentId: nextEnv.id,
      phase: EnvironmentPhase.Training,
      bossDefeated: false,
      tournamentVictories: 0,
      tournamentDefeated: false,
    };
  }

  // Track full theme cycles (every 4 environments completes one cycle)
  const currentThemeIndex = THEME_ORDER.indexOf(nextEnv.combatTheme);
  if (currentThemeIndex === 0 && nextIndex > 0) {
    state.themeCyclesCompleted++;
  }

  return nextEnv;
}

/** Record a tournament victory in the current environment. */
export function recordTournamentVictory(state: ProgressionState): void {
  const env = currentEnvironment(state);
  const progress = state.environmentProgress[env.id];
  if (progress) {
    progress.tournamentVictories++;
  }
}

/** Record a tournament defeat in the current environment. */
export function recordTournamentDefeat(state: ProgressionState): void {
  const env = currentEnvironment(state);
  const progress = state.environmentProgress[env.id];
  if (progress) {
    progress.tournamentDefeated = true;
  }
}
