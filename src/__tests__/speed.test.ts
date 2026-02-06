import { describe, it, expect } from "vitest";
import {
  BASE_SPEED,
  PEDOMETER_SPEED_CAP_PERCENT,
  TileType,
  TILE_DEFINITIONS,
  SpeedStatus,
  createSpeedState,
  applyPedometerSpeedUpgrade,
  isPedometerSpeedCapped,
  effectiveSpeed,
  minimumSpeedForTier,
  speedStatusForTier,
} from "../core/speed.js";

describe("SpeedState", () => {
  it("starts at base speed with no bonuses", () => {
    const s = createSpeedState();
    expect(effectiveSpeed(s)).toBe(BASE_SPEED);
    expect(s.pedometerBonusPercent).toBe(0);
  });

  it("pedometer upgrades increase speed", () => {
    const s = createSpeedState();
    applyPedometerSpeedUpgrade(s, 50);
    expect(effectiveSpeed(s)).toBe(BASE_SPEED * 1.5);
  });

  it("pedometer upgrades are capped at 500%", () => {
    const s = createSpeedState();
    applyPedometerSpeedUpgrade(s, 600);
    expect(s.pedometerBonusPercent).toBe(PEDOMETER_SPEED_CAP_PERCENT);
    expect(isPedometerSpeedCapped(s)).toBe(true);
  });

  it("tile and temp bonuses stack additively", () => {
    const s = createSpeedState();
    applyPedometerSpeedUpgrade(s, 100);
    s.tileBonusPercent = 50;
    s.tempBonusPercent = 25;
    // total bonus = 100 + 50 + 25 = 175%
    expect(effectiveSpeed(s)).toBe(BASE_SPEED * 2.75);
  });

  it("tile bonus is uncapped even if pedometer is capped", () => {
    const s = createSpeedState();
    applyPedometerSpeedUpgrade(s, PEDOMETER_SPEED_CAP_PERCENT);
    s.tileBonusPercent = 200;
    // 500 + 200 = 700% bonus
    expect(effectiveSpeed(s)).toBe(BASE_SPEED * 8);
  });
});

describe("tile definitions", () => {
  it("dirt path is cheapest", () => {
    expect(TILE_DEFINITIONS[TileType.DirtPath].goldCost).toBe(100);
  });

  it("teleport pad is most expensive", () => {
    expect(TILE_DEFINITIONS[TileType.TeleportPad].goldCost).toBe(50_000);
  });

  it("speed rail has highest speed bonus", () => {
    const bonuses = Object.values(TILE_DEFINITIONS).map(
      (t) => t.speedBonusPercent,
    );
    expect(
      TILE_DEFINITIONS[TileType.SpeedRail].speedBonusPercent,
    ).toBe(Math.max(...bonuses));
  });
});

describe("environment speed requirements", () => {
  it("tier 1 has no requirement (100)", () => {
    expect(minimumSpeedForTier(1)).toBe(100);
  });

  it("tier 5 requires 500", () => {
    expect(minimumSpeedForTier(5)).toBe(500);
  });

  it("tier 6+ defaults to 500", () => {
    expect(minimumSpeedForTier(6)).toBe(500);
    expect(minimumSpeedForTier(10)).toBe(500);
  });
});

describe("speedStatusForTier", () => {
  it("below minimum → BelowMinimum", () => {
    expect(speedStatusForTier(100, 2)).toBe(SpeedStatus.BelowMinimum);
  });

  it("at minimum → Normal", () => {
    expect(speedStatusForTier(150, 2)).toBe(SpeedStatus.Normal);
  });

  it("25%+ above minimum → Advantaged", () => {
    // min for tier 2 is 150, 150 * 1.25 = 187.5
    expect(speedStatusForTier(188, 2)).toBe(SpeedStatus.Advantaged);
  });
});
