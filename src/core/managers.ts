/**
 * Manager & Automation system.
 *
 * Tier 1: Task Managers   – automate a single training activity at 50% base efficiency
 * Tier 2: Department Mgrs – +25% to managed Task Managers
 * Tier 3: VP of Training  – +50% to all, auto-hire feature
 * Tier 4: CEO             – prestige multiplier, unlocks Tier 5
 * Tier 5: Regional Mgrs   – post-prestige, environment-scoped automation
 *
 * Stacking Task Managers has diminishing returns: 50%, 75%, 87.5%, …
 * Efficiency cap: automation can never exceed 100% of the active rate.
 */

import { TrainingActivity } from "./variables.js";

// ---------------------------------------------------------------------------
// Task Manager types
// ---------------------------------------------------------------------------

export enum TaskManagerType {
  MiningForeman = "mining_foreman",
  CourseInstructor = "course_instructor",
  MeditationGuide = "meditation_guide",
  RunningCoach = "running_coach",
}

/** Which training activity each task manager automates. */
export const TASK_MANAGER_ACTIVITY: Record<TaskManagerType, TrainingActivity> = {
  [TaskManagerType.MiningForeman]: TrainingActivity.Mining,
  [TaskManagerType.CourseInstructor]: TrainingActivity.ObstacleCourse,
  [TaskManagerType.MeditationGuide]: TrainingActivity.Meditation,
  [TaskManagerType.RunningCoach]: TrainingActivity.DistanceRunning,
};

/** Which "department" category each task manager belongs to. */
export enum ManagerCategory {
  Physical = "physical",
  Mental = "mental",
}

export const TASK_MANAGER_CATEGORY: Record<TaskManagerType, ManagerCategory> = {
  [TaskManagerType.MiningForeman]: ManagerCategory.Physical,
  [TaskManagerType.CourseInstructor]: ManagerCategory.Mental,
  [TaskManagerType.MeditationGuide]: ManagerCategory.Mental,
  [TaskManagerType.RunningCoach]: ManagerCategory.Physical,
};

// ---------------------------------------------------------------------------
// Cost calculations
// ---------------------------------------------------------------------------

/** Base cost for the first task manager of any type. */
export const TASK_MANAGER_BASE_COST = 1_000;
export const DEPARTMENT_MANAGER_COST = 10_000;
export const VP_COST = 100_000;
export const CEO_COST = 1_000_000;

/**
 * Cost of the Nth task manager of a given type.
 * Formula: BaseCost × 2^(n-1) where n is 1-indexed count.
 */
export function taskManagerCost(ownedCount: number): number {
  return TASK_MANAGER_BASE_COST * Math.pow(2, ownedCount);
}

/**
 * Total gold invested after purchasing N task managers of one type.
 * Sum of geometric series: BaseCost × (2^N - 1)
 */
export function totalTaskManagerInvestment(count: number): number {
  if (count <= 0) return 0;
  return TASK_MANAGER_BASE_COST * (Math.pow(2, count) - 1);
}

// ---------------------------------------------------------------------------
// Manager state
// ---------------------------------------------------------------------------

export interface ManagerState {
  /** Count of each type of task manager owned. */
  taskManagers: Record<TaskManagerType, number>;

  /** Whether each department manager is owned. */
  physicalDirector: boolean;
  mentalDirector: boolean;

  /** Whether the VP is owned. */
  vpOfTraining: boolean;
  /** Whether VP auto-hire is enabled. */
  vpAutoHireEnabled: boolean;

  /** Whether the CEO is owned. */
  ceo: boolean;

  /** Current prestige level (0 = no prestige yet). */
  prestigeLevel: number;
}

export function createManagerState(): ManagerState {
  return {
    taskManagers: {
      [TaskManagerType.MiningForeman]: 0,
      [TaskManagerType.CourseInstructor]: 0,
      [TaskManagerType.MeditationGuide]: 0,
      [TaskManagerType.RunningCoach]: 0,
    },
    physicalDirector: false,
    mentalDirector: false,
    vpOfTraining: false,
    vpAutoHireEnabled: false,
    ceo: false,
    prestigeLevel: 0,
  };
}

// ---------------------------------------------------------------------------
// Unlock checks
// ---------------------------------------------------------------------------

/** A department manager is unlockable when the player owns 2+ task managers in its category. */
export function canUnlockDepartmentManager(
  state: ManagerState,
  category: ManagerCategory,
): boolean {
  let count = 0;
  for (const [type, qty] of Object.entries(state.taskManagers)) {
    if (TASK_MANAGER_CATEGORY[type as TaskManagerType] === category) {
      count += qty;
    }
  }
  return count >= 2;
}

export function canUnlockVP(state: ManagerState): boolean {
  return state.physicalDirector && state.mentalDirector;
}

export function canUnlockCEO(
  state: ManagerState,
  hasCompletedThemeCycle: boolean,
): boolean {
  return state.vpOfTraining && hasCompletedThemeCycle;
}

// ---------------------------------------------------------------------------
// Efficiency calculations
// ---------------------------------------------------------------------------

/**
 * Stack efficiency for N task managers of the same type.
 *
 * Diminishing returns: each additional manager adds half as much as the previous.
 *   Manager 1: 0.50
 *   Manager 2: 0.50 + 0.25 = 0.75
 *   Manager 3: 0.75 + 0.125 = 0.875
 *   …
 *   Asymptotic limit: 1.0 (100%)
 *
 * Formula: 1 - (0.5 ^ count)
 */
export function stackEfficiency(count: number): number {
  if (count <= 0) return 0;
  return 1 - Math.pow(0.5, count);
}

/**
 * Calculate the final automation efficiency for a specific task manager type.
 *
 * Final = StackEfficiency × DepartmentBonus × ExecutiveBonus × PrestigeMultiplier
 * Capped at 1.0 (100%).
 */
export function automationEfficiency(
  state: ManagerState,
  type: TaskManagerType,
): number {
  const count = state.taskManagers[type];
  if (count === 0) return 0;

  const base = stackEfficiency(count);

  const category = TASK_MANAGER_CATEGORY[type];
  const hasDepartment =
    category === ManagerCategory.Physical
      ? state.physicalDirector
      : state.mentalDirector;
  const departmentBonus = hasDepartment ? 1.25 : 1.0;

  const executiveBonus = state.vpOfTraining ? 1.5 : 1.0;
  const prestigeMultiplier = 1.0 + 0.1 * state.prestigeLevel;

  const raw = base * departmentBonus * executiveBonus * prestigeMultiplier;
  return Math.min(raw, 1.0); // cap at 100%
}

/**
 * Calculate the passive training gains per hour for a given task manager type.
 *
 * The active casual rate for all activities is 10/hour.
 * Automation efficiency is a fraction of that active rate.
 */
export const CASUAL_ACTIVE_RATE_PER_HOUR = 10;

export function passiveGainsPerHour(
  state: ManagerState,
  type: TaskManagerType,
): number {
  return automationEfficiency(state, type) * CASUAL_ACTIVE_RATE_PER_HOUR;
}

// ---------------------------------------------------------------------------
// Prestige
// ---------------------------------------------------------------------------

export function prestigeMultiplier(level: number): number {
  return 1.0 + 0.1 * level;
}

export interface PrestigeResult {
  newPrestigeLevel: number;
  multiplier: number;
}

/**
 * Execute a prestige (Corporate Restructuring).
 * Resets all managers, increments prestige level, returns new multiplier.
 */
export function performPrestige(state: ManagerState): PrestigeResult {
  state.prestigeLevel++;
  const mult = prestigeMultiplier(state.prestigeLevel);

  // Reset all managers
  for (const type of Object.values(TaskManagerType)) {
    state.taskManagers[type] = 0;
  }
  state.physicalDirector = false;
  state.mentalDirector = false;
  state.vpOfTraining = false;
  state.vpAutoHireEnabled = false;
  state.ceo = false;

  return { newPrestigeLevel: state.prestigeLevel, multiplier: mult };
}
