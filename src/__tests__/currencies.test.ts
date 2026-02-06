import { describe, it, expect } from "vitest";
import {
  createPowerLevel,
  addPowerLevel,
  createPedometer,
  addSteps,
  pedometerSpeedBonus,
  currentMilestone,
  spendPedometer,
  createGold,
  earnGold,
  spendGold,
  PEDOMETER_MILESTONES,
} from "../core/currencies.js";

// ---------------------------------------------------------------------------
// Power Level
// ---------------------------------------------------------------------------

describe("PowerLevel", () => {
  it("starts at 1", () => {
    const pl = createPowerLevel();
    expect(pl.value).toBe(1);
  });

  it("increases by positive amounts", () => {
    const pl = createPowerLevel();
    addPowerLevel(pl, 10);
    expect(pl.value).toBe(11);
  });

  it("ignores negative amounts (never decreases)", () => {
    const pl = createPowerLevel();
    addPowerLevel(pl, 10);
    addPowerLevel(pl, -5);
    expect(pl.value).toBe(11);
  });

  it("ignores zero", () => {
    const pl = createPowerLevel();
    addPowerLevel(pl, 0);
    expect(pl.value).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// Pedometer
// ---------------------------------------------------------------------------

describe("Pedometer", () => {
  it("starts at 0 count and 0 lifetime", () => {
    const p = createPedometer();
    expect(p.count).toBe(0);
    expect(p.lifetimeSteps).toBe(0);
    expect(p.timesSpent).toBe(0);
  });

  it("accumulates steps", () => {
    const p = createPedometer();
    addSteps(p, 100);
    addSteps(p, 200);
    expect(p.count).toBe(300);
    expect(p.lifetimeSteps).toBe(300);
  });

  it("ignores negative steps", () => {
    const p = createPedometer();
    addSteps(p, 100);
    addSteps(p, -50);
    expect(p.count).toBe(100);
  });

  it("spendPedometer resets count to 0 and returns result", () => {
    const p = createPedometer();
    addSteps(p, 10_000);
    const result = spendPedometer(p);
    expect(result.stepsSpent).toBe(10_000);
    expect(result.speedBonusPercent).toBeCloseTo(40); // log10(10000) * 10
    expect(p.count).toBe(0);
    expect(p.timesSpent).toBe(1);
    // lifetime is preserved
    expect(p.lifetimeSteps).toBe(10_000);
  });

  it("spending with 0 steps yields 0 bonus", () => {
    const p = createPedometer();
    const result = spendPedometer(p);
    expect(result.stepsSpent).toBe(0);
    expect(result.speedBonusPercent).toBe(0);
  });
});

describe("pedometerSpeedBonus", () => {
  it("returns 0 for 0 or negative steps", () => {
    expect(pedometerSpeedBonus(0)).toBe(0);
    expect(pedometerSpeedBonus(-1)).toBe(0);
  });

  it("matches design doc examples", () => {
    expect(pedometerSpeedBonus(1_000)).toBeCloseTo(30);
    expect(pedometerSpeedBonus(10_000)).toBeCloseTo(40);
    expect(pedometerSpeedBonus(100_000)).toBeCloseTo(50);
  });
});

describe("currentMilestone", () => {
  it("returns null below first milestone", () => {
    expect(currentMilestone(999)).toBeNull();
  });

  it("returns the highest reached milestone", () => {
    expect(currentMilestone(1_000)?.steps).toBe(1_000);
    expect(currentMilestone(50_000)?.steps).toBe(10_000);
    expect(currentMilestone(10_000_000)?.steps).toBe(10_000_000);
  });
});

// ---------------------------------------------------------------------------
// Gold
// ---------------------------------------------------------------------------

describe("Gold", () => {
  it("starts at 0", () => {
    const g = createGold();
    expect(g.amount).toBe(0);
    expect(g.lifetimeEarned).toBe(0);
  });

  it("earn increases amount and lifetime", () => {
    const g = createGold();
    earnGold(g, 500);
    expect(g.amount).toBe(500);
    expect(g.lifetimeEarned).toBe(500);
  });

  it("earning negative amounts is ignored", () => {
    const g = createGold();
    earnGold(g, 500);
    earnGold(g, -100);
    expect(g.amount).toBe(500);
  });

  it("spend deducts gold and returns true on success", () => {
    const g = createGold();
    earnGold(g, 1000);
    expect(spendGold(g, 400)).toBe(true);
    expect(g.amount).toBe(600);
  });

  it("spend returns false and does not deduct when insufficient", () => {
    const g = createGold();
    earnGold(g, 100);
    expect(spendGold(g, 200)).toBe(false);
    expect(g.amount).toBe(100);
  });

  it("spending 0 or negative always succeeds", () => {
    const g = createGold();
    expect(spendGold(g, 0)).toBe(true);
    expect(spendGold(g, -5)).toBe(true);
  });
});
