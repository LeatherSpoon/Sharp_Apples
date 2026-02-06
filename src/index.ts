/**
 * MyRPG Core Numbers — public API surface.
 *
 * Re-exports every type, constant, and function from the core modules
 * so consumers can import from a single entry point.
 */

// Currencies
export {
  type PowerLevelState,
  type PedometerState,
  type GoldState,
  type PedometerSpendResult,
  PEDOMETER_MILESTONES,
  createPowerLevel,
  effectivePowerLevel,
  earnPowerLevel,
  spendPowerLevel,
  buyPermanentUpgrade,
  resetPowerLevel,
  addPermanentPowerLevel,
  createPedometer,
  addSteps,
  pedometerSpeedBonus,
  currentMilestone,
  spendPedometer,
  createGold,
  earnGold,
  spendGold,
} from "./core/currencies.js";

// Controlling Variables
export {
  VariableKind,
  TrainingActivity,
  TrainingIntensity,
  type ControllingVariables,
  type VariableEffects,
  type ThemeBonusKey,
  VARIABLE_TRAINING_MAP,
  VARIABLE_EFFECTS,
  BASE_HP,
  BASE_ENERGY_POOL,
  BASE_ENERGY_REGEN,
  createControllingVariables,
  trainVariable,
  variableScaling,
  maxHP,
  energyPoolSize,
  energyRegenRate,
} from "./core/variables.js";

// Combat Themes & Mastery
export {
  CombatTheme,
  THEME_ORDER,
  MAX_MASTERY_LEVEL,
  type ThemeDefinition,
  type ThemeMastery,
  type MasteryState,
  type DamageParams,
  THEME_DEFINITIONS,
  nextThemeInCycle,
  masteryXPRequired,
  createMasteryState,
  awardMasteryXP,
  isThemeUnlocked,
  crossThemeMasteryBonus,
  calculateDamage,
  tournamentOpponentPower,
  isExpectedLoss,
} from "./core/combat.js";

// Speed & Movement
export {
  TileType,
  SpeedStatus,
  type TileDefinition,
  type SpeedState,
  type EnvironmentSpeedRequirement,
  BASE_SPEED,
  PEDOMETER_SPEED_CAP_PERCENT,
  TILE_DEFINITIONS,
  ENVIRONMENT_SPEED_REQUIREMENTS,
  createSpeedState,
  applyPedometerSpeedUpgrade,
  isPedometerSpeedCapped,
  effectiveSpeed,
  minimumSpeedForTier,
  speedStatusForTier,
} from "./core/speed.js";

// Managers & Automation
export {
  TaskManagerType,
  ManagerCategory,
  type ManagerState,
  type PrestigeResult,
  TASK_MANAGER_ACTIVITY,
  TASK_MANAGER_CATEGORY,
  TASK_MANAGER_BASE_COST,
  DEPARTMENT_MANAGER_COST,
  VP_COST,
  CEO_COST,
  CASUAL_ACTIVE_RATE_PER_HOUR,
  createManagerState,
  taskManagerCost,
  totalTaskManagerInvestment,
  canUnlockDepartmentManager,
  canUnlockVP,
  canUnlockCEO,
  stackEfficiency,
  automationEfficiency,
  passiveGainsPerHour,
  prestigeMultiplier,
  performPrestige,
} from "./core/managers.js";

// Environments & Progression
export {
  EnvironmentPhase,
  type EnvironmentDefinition,
  type EnvironmentProgress,
  type ProgressionState,
  ENVIRONMENTS,
  createProgressionState,
  currentEnvironment,
  currentCombatTheme,
  advanceEnvironment,
  recordTournamentVictory,
  recordTournamentDefeat,
} from "./core/environment.js";

// Game State (central container)
export {
  type GameState,
  type MasterResetResult,
  createGameState,
  tickManagers,
  tickMovement,
  spendPedometerForUpgrade,
  requiredCombatTheme,
  getEffectivePowerLevel,
  performMasterReset,
  tick,
} from "./core/game-state.js";
