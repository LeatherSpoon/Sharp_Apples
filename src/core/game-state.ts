/**
 * Central GameState that ties every core system together.
 *
 * This is the single source of truth for a player's save data.
 * All mutations go through dedicated system functions; this module
 * provides the top-level container and convenience tick/update helpers.
 */

import {
  type PowerLevelState,
  type PedometerState,
  type GoldState,
  createPowerLevel,
  createPedometer,
  createGold,
  addSteps,
  spendPedometer,
  effectivePowerLevel,
  addPermanentPowerLevel,
  resetPowerLevel,
} from "./currencies.js";

import {
  type ControllingVariables,
  VariableKind,
  createControllingVariables,
  trainVariable,
} from "./variables.js";

import {
  CombatTheme,
  type MasteryState,
  createMasteryState,
} from "./combat.js";

import {
  type SpeedState,
  createSpeedState,
  applyPedometerSpeedUpgrade,
  effectiveSpeed,
  isPedometerSpeedCapped,
} from "./speed.js";

import {
  type ManagerState,
  createManagerState,
  TaskManagerType,
  TASK_MANAGER_ACTIVITY,
  passiveGainsPerHour,
} from "./managers.js";

import {
  type ProgressionState,
  createProgressionState,
  currentCombatTheme,
  advanceEnvironment,
} from "./environment.js";

import { TrainingActivity } from "./variables.js";

// ---------------------------------------------------------------------------
// Game state container
// ---------------------------------------------------------------------------

export interface GameState {
  /** Core currencies */
  powerLevel: PowerLevelState;
  pedometer: PedometerState;
  gold: GoldState;

  /** The four controlling variables */
  variables: ControllingVariables;

  /** Per-theme mastery tracking */
  mastery: MasteryState;

  /** Currently active combat theme */
  activeCombatTheme: CombatTheme;

  /** Speed / movement */
  speed: SpeedState;

  /** Manager / automation hierarchy */
  managers: ManagerState;

  /** Environment progression */
  progression: ProgressionState;

  /** Total play time in seconds (for stats). */
  totalPlayTimeSeconds: number;
}

export function createGameState(): GameState {
  return {
    powerLevel: createPowerLevel(),
    pedometer: createPedometer(),
    gold: createGold(),
    variables: createControllingVariables(),
    mastery: createMasteryState(),
    activeCombatTheme: CombatTheme.Unarmed,
    speed: createSpeedState(),
    managers: createManagerState(),
    progression: createProgressionState(),
    totalPlayTimeSeconds: 0,
  };
}

// ---------------------------------------------------------------------------
// Activity → Variable mapping (reverse of VARIABLE_TRAINING_MAP)
// ---------------------------------------------------------------------------

const ACTIVITY_TO_VARIABLE: Record<TrainingActivity, VariableKind> = {
  [TrainingActivity.Mining]: VariableKind.Strength,
  [TrainingActivity.ObstacleCourse]: VariableKind.Dexterity,
  [TrainingActivity.Meditation]: VariableKind.Focus,
  [TrainingActivity.DistanceRunning]: VariableKind.Endurance,
};

// ---------------------------------------------------------------------------
// Tick / update helpers
// ---------------------------------------------------------------------------

/**
 * Process passive manager gains for a given elapsed time (in seconds).
 *
 * Call this once per game tick (or on load for offline progress).
 * Returns the total variable gains applied.
 */
export function tickManagers(
  state: GameState,
  elapsedSeconds: number,
): Record<VariableKind, number> {
  const gains: Record<VariableKind, number> = {
    [VariableKind.Strength]: 0,
    [VariableKind.Dexterity]: 0,
    [VariableKind.Focus]: 0,
    [VariableKind.Endurance]: 0,
  };

  const elapsedHours = elapsedSeconds / 3600;

  for (const type of Object.values(TaskManagerType)) {
    const gainsPerHour = passiveGainsPerHour(state.managers, type);
    if (gainsPerHour <= 0) continue;

    const activity = TASK_MANAGER_ACTIVITY[type];
    const variable = ACTIVITY_TO_VARIABLE[activity];
    const amount = gainsPerHour * elapsedHours;

    trainVariable(state.variables, variable, amount);
    gains[variable] += amount;
  }

  return gains;
}

/**
 * Process movement tick — adds steps based on current speed and elapsed time.
 */
export function tickMovement(state: GameState, elapsedSeconds: number): number {
  const speed = effectiveSpeed(state.speed);
  // 1 step per unit of distance; speed is in units/second
  const steps = speed * elapsedSeconds;
  addSteps(state.pedometer, steps);
  return steps;
}

/**
 * Spend the pedometer and apply the speed upgrade (or permanent PL bonus
 * if speed is already capped).
 */
export function spendPedometerForUpgrade(state: GameState): {
  stepsSpent: number;
  speedBonusApplied: number;
  powerLevelBonusApplied: number;
} {
  const result = spendPedometer(state.pedometer);

  let speedBonusApplied = 0;
  let powerLevelBonusApplied = 0;

  if (!isPedometerSpeedCapped(state.speed)) {
    speedBonusApplied = result.speedBonusPercent;
    applyPedometerSpeedUpgrade(state.speed, result.speedBonusPercent);
  } else {
    // Speed is capped — award permanent Power Level bonus instead
    powerLevelBonusApplied = Math.floor(result.speedBonusPercent / 10);
    addPermanentPowerLevel(state.powerLevel, powerLevelBonusApplied);
  }

  return {
    stepsSpent: result.stepsSpent,
    speedBonusApplied,
    powerLevelBonusApplied,
  };
}

/**
 * Get the combat theme dictated by the current environment.
 */
export function requiredCombatTheme(state: GameState): CombatTheme {
  return currentCombatTheme(state.progression);
}

/** Get the effective PL for display / combat formulas. */
export function getEffectivePowerLevel(state: GameState): number {
  return effectivePowerLevel(state.powerLevel);
}

// ---------------------------------------------------------------------------
// Master reset (new master transition)
// ---------------------------------------------------------------------------

export interface MasterResetResult {
  /** Current PL that was lost. */
  currentPLLost: number;
  /** The new environment name (or null if no more authored environments). */
  newEnvironmentName: string | null;
  /** The combat theme of the new environment. */
  newTheme: CombatTheme | null;
}

/**
 * Perform a master reset: advance to the next environment, reset current PL
 * to 1, preserve permanent PL. Called after tournament defeat.
 *
 * This is the core "rebirth" loop of the game. The player loses their
 * current PL investment but keeps everything permanent, arriving at a new
 * master stronger than they started the previous cycle.
 */
export function performMasterReset(state: GameState): MasterResetResult {
  const currentPLLost = resetPowerLevel(state.powerLevel);

  const newEnv = advanceEnvironment(state.progression);

  if (newEnv) {
    state.activeCombatTheme = newEnv.combatTheme;
  }

  return {
    currentPLLost,
    newEnvironmentName: newEnv?.name ?? null,
    newTheme: newEnv?.combatTheme ?? null,
  };
}

// ---------------------------------------------------------------------------
// Master tick
// ---------------------------------------------------------------------------

/**
 * Master game-loop tick. Call once per frame / interval.
 *
 * Handles: manager passive gains, movement/steps, play time tracking.
 */
export function tick(
  state: GameState,
  elapsedSeconds: number,
  isMoving: boolean,
): void {
  state.totalPlayTimeSeconds += elapsedSeconds;

  // Passive manager gains always run
  tickManagers(state, elapsedSeconds);

  // Movement generates steps
  if (isMoving) {
    tickMovement(state, elapsedSeconds);
  }
}
