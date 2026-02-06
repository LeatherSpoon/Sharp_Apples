import { describe, it, expect } from "vitest";
import {
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
} from "../core/currencies.js";

// ---------------------------------------------------------------------------
// Power Level (NGU Idle-style)
// ---------------------------------------------------------------------------

describe("PowerLevel", () => {
  it("starts at current=1, permanent=0", () => {
    const pl = createPowerLevel();
    expect(pl.current).toBe(1);
    expect(pl.permanent).toBe(0);
    expect(pl.lifetimeEarned).toBe(0);
    expect(pl.lifetimeSpent).toBe(0);
    expect(pl.timesReset).toBe(0);
  });

  it("effective PL = permanent + current", () => {
    const pl = createPowerLevel();
    expect(effectivePowerLevel(pl)).toBe(1); // 0 + 1
    pl.permanent = 50;
    expect(effectivePowerLevel(pl)).toBe(51); // 50 + 1
  });
});

describe("earnPowerLevel", () => {
  it("increases current PL and lifetime", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 10);
    expect(pl.current).toBe(11);
    expect(pl.lifetimeEarned).toBe(10);
  });

  it("ignores negative and zero amounts", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, -5);
    earnPowerLevel(pl, 0);
    expect(pl.current).toBe(1);
    expect(pl.lifetimeEarned).toBe(0);
  });
});

describe("spendPowerLevel (iterative upgrades)", () => {
  it("deducts current PL and returns true when affordable", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 99); // current = 100
    expect(spendPowerLevel(pl, 40)).toBe(true);
    expect(pl.current).toBe(60);
    expect(pl.lifetimeSpent).toBe(40);
  });

  it("returns false and does nothing when insufficient", () => {
    const pl = createPowerLevel();
    expect(spendPowerLevel(pl, 5)).toBe(false);
    expect(pl.current).toBe(1); // unchanged
  });

  it("spending 0 or negative always succeeds", () => {
    const pl = createPowerLevel();
    expect(spendPowerLevel(pl, 0)).toBe(true);
    expect(spendPowerLevel(pl, -10)).toBe(true);
  });

  it("current PL can go down to 0", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 9); // current = 10
    expect(spendPowerLevel(pl, 10)).toBe(true);
    expect(pl.current).toBe(0);
  });
});

describe("buyPermanentUpgrade", () => {
  it("spends current PL and adds to permanent PL", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 99); // current = 100
    expect(buyPermanentUpgrade(pl, 100, 10)).toBe(true);
    expect(pl.current).toBe(0);
    expect(pl.permanent).toBe(10);
    expect(pl.lifetimeSpent).toBe(100);
  });

  it("fails when insufficient current PL", () => {
    const pl = createPowerLevel();
    expect(buyPermanentUpgrade(pl, 50, 5)).toBe(false);
    expect(pl.permanent).toBe(0);
  });

  it("conversion rate can differ from cost", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 999); // current = 1000
    buyPermanentUpgrade(pl, 500, 25); // spend 500, get 25 perm
    expect(pl.current).toBe(500);
    expect(pl.permanent).toBe(25);
    expect(effectivePowerLevel(pl)).toBe(525);
  });
});

describe("resetPowerLevel (master transition)", () => {
  it("resets current to 1 and preserves permanent", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 999); // current = 1000
    pl.permanent = 50;
    const lost = resetPowerLevel(pl);

    expect(lost).toBe(1000);
    expect(pl.current).toBe(1);
    expect(pl.permanent).toBe(50); // preserved
    expect(pl.timesReset).toBe(1);
  });

  it("repeated resets increment counter", () => {
    const pl = createPowerLevel();
    resetPowerLevel(pl);
    resetPowerLevel(pl);
    resetPowerLevel(pl);
    expect(pl.timesReset).toBe(3);
    expect(pl.current).toBe(1); // always 1 after reset
  });

  it("effective PL is permanent + 1 after reset", () => {
    const pl = createPowerLevel();
    earnPowerLevel(pl, 99);
    buyPermanentUpgrade(pl, 50, 10); // perm = 10
    resetPowerLevel(pl);
    expect(effectivePowerLevel(pl)).toBe(11); // 10 + 1
  });
});

describe("addPermanentPowerLevel", () => {
  it("adds directly to permanent (for achievements, etc)", () => {
    const pl = createPowerLevel();
    addPermanentPowerLevel(pl, 25);
    expect(pl.permanent).toBe(25);
    expect(effectivePowerLevel(pl)).toBe(26); // 25 + 1
  });

  it("ignores negative amounts", () => {
    const pl = createPowerLevel();
    addPermanentPowerLevel(pl, -10);
    expect(pl.permanent).toBe(0);
  });
});

describe("PowerLevel full cycle (NGU Idle loop)", () => {
  it("simulates a multi-master progression cycle", () => {
    const pl = createPowerLevel();

    // === Master 1 ===
    earnPowerLevel(pl, 99); // train up to 100 current
    expect(effectivePowerLevel(pl)).toBe(100);

    // Spend some on iterative upgrades
    spendPowerLevel(pl, 30); // 70 current left

    // Buy a permanent upgrade before the reset
    buyPermanentUpgrade(pl, 50, 5); // spend 50 current → +5 permanent
    expect(pl.current).toBe(20);
    expect(pl.permanent).toBe(5);

    // Tournament defeat → master reset
    resetPowerLevel(pl);
    expect(pl.current).toBe(1);
    expect(pl.permanent).toBe(5);
    expect(effectivePowerLevel(pl)).toBe(6); // stronger baseline than cycle 1

    // === Master 2 ===
    earnPowerLevel(pl, 149); // train up to 150 current
    expect(effectivePowerLevel(pl)).toBe(155); // 5 + 150

    // More permanent upgrades
    buyPermanentUpgrade(pl, 100, 10); // spend 100 → +10 perm
    expect(pl.permanent).toBe(15);

    resetPowerLevel(pl);
    expect(effectivePowerLevel(pl)).toBe(16); // even stronger baseline

    // Lifetime tracking
    expect(pl.lifetimeEarned).toBe(99 + 149);
    expect(pl.timesReset).toBe(2);
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
