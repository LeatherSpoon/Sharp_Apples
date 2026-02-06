/**
 * Speed and movement system.
 *
 * Speed is derived from:
 *   1. Base speed (100 units/s)
 *   2. Pedometer-purchased permanent upgrades (capped at +500%)
 *   3. Speed tiles placed on the map (uncapped)
 *   4. Temporary equipment/consumable bonuses
 *
 * Higher environments require minimum speeds. Below minimum the player
 * is severely penalized; at or above minimum is normal; above gives advantage.
 */

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

export const BASE_SPEED = 100;

/** Maximum bonus from pedometer upgrades as a percentage. */
export const PEDOMETER_SPEED_CAP_PERCENT = 500;

// ---------------------------------------------------------------------------
// Speed tiles
// ---------------------------------------------------------------------------

export enum TileType {
  DirtPath = "dirt_path",
  Cobblestone = "cobblestone",
  PavedRoad = "paved_road",
  SpeedRail = "speed_rail",
  TeleportPad = "teleport_pad",
}

export interface TileDefinition {
  type: TileType;
  speedBonusPercent: number;
  goldCost: number;
  /** Tile footprint, e.g. "1x1" or "1x3". */
  size: string;
}

export const TILE_DEFINITIONS: Record<TileType, TileDefinition> = {
  [TileType.DirtPath]: {
    type: TileType.DirtPath,
    speedBonusPercent: 10,
    goldCost: 100,
    size: "1x1",
  },
  [TileType.Cobblestone]: {
    type: TileType.Cobblestone,
    speedBonusPercent: 25,
    goldCost: 500,
    size: "1x1",
  },
  [TileType.PavedRoad]: {
    type: TileType.PavedRoad,
    speedBonusPercent: 50,
    goldCost: 2_500,
    size: "1x1",
  },
  [TileType.SpeedRail]: {
    type: TileType.SpeedRail,
    speedBonusPercent: 100,
    goldCost: 10_000,
    size: "1x3",
  },
  [TileType.TeleportPad]: {
    type: TileType.TeleportPad,
    speedBonusPercent: 0, // instant travel (special case)
    goldCost: 50_000,
    size: "1x1",
  },
};

// ---------------------------------------------------------------------------
// Speed state
// ---------------------------------------------------------------------------

export interface SpeedState {
  /**
   * Permanent speed bonus from pedometer spending (percentage points).
   * Capped at PEDOMETER_SPEED_CAP_PERCENT.
   */
  pedometerBonusPercent: number;

  /**
   * Current tile bonus at the player's position (percentage points).
   * Set dynamically based on what tile the player stands on.
   */
  tileBonusPercent: number;

  /**
   * Temporary bonus from equipment and consumables (percentage points).
   */
  tempBonusPercent: number;
}

export function createSpeedState(): SpeedState {
  return {
    pedometerBonusPercent: 0,
    tileBonusPercent: 0,
    tempBonusPercent: 0,
  };
}

/**
 * Apply a permanent speed upgrade from a pedometer spend.
 * Enforces the cap.
 */
export function applyPedometerSpeedUpgrade(
  state: SpeedState,
  bonusPercent: number,
): void {
  state.pedometerBonusPercent = Math.min(
    state.pedometerBonusPercent + bonusPercent,
    PEDOMETER_SPEED_CAP_PERCENT,
  );
}

/** Whether the pedometer speed cap has been reached. */
export function isPedometerSpeedCapped(state: SpeedState): boolean {
  return state.pedometerBonusPercent >= PEDOMETER_SPEED_CAP_PERCENT;
}

/**
 * Calculate current effective speed in units/second.
 *
 * All bonuses are additive percentages applied to BASE_SPEED:
 *   effectiveSpeed = BASE_SPEED × (1 + totalBonusPercent / 100)
 */
export function effectiveSpeed(state: SpeedState): number {
  const totalPercent =
    state.pedometerBonusPercent + state.tileBonusPercent + state.tempBonusPercent;
  return BASE_SPEED * (1 + totalPercent / 100);
}

// ---------------------------------------------------------------------------
// Environment speed requirements
// ---------------------------------------------------------------------------

export interface EnvironmentSpeedRequirement {
  tier: number;
  minimumSpeed: number;
}

export const ENVIRONMENT_SPEED_REQUIREMENTS: EnvironmentSpeedRequirement[] = [
  { tier: 1, minimumSpeed: 100 },
  { tier: 2, minimumSpeed: 150 },
  { tier: 3, minimumSpeed: 225 },
  { tier: 4, minimumSpeed: 350 },
  { tier: 5, minimumSpeed: 500 },
];

/** Get the minimum speed for a given environment tier. Tier 6+ use 500. */
export function minimumSpeedForTier(tier: number): number {
  const entry = ENVIRONMENT_SPEED_REQUIREMENTS.find((e) => e.tier === tier);
  if (entry) return entry.minimumSpeed;
  return tier >= 6 ? 500 : 100;
}

export enum SpeedStatus {
  /** Below minimum — severe movement penalty. */
  BelowMinimum = "below_minimum",
  /** At or near minimum — normal gameplay. */
  Normal = "normal",
  /** Above minimum — advantageous positioning. */
  Advantaged = "advantaged",
}

export function speedStatusForTier(
  currentSpeed: number,
  tier: number,
): SpeedStatus {
  const min = minimumSpeedForTier(tier);
  if (currentSpeed < min) return SpeedStatus.BelowMinimum;
  if (currentSpeed >= min * 1.25) return SpeedStatus.Advantaged;
  return SpeedStatus.Normal;
}
