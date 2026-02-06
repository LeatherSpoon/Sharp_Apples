import { describe, it, expect } from "vitest";
import {
  CombatTheme,
  THEME_ORDER,
  nextThemeInCycle,
  masteryXPRequired,
  createMasteryState,
  awardMasteryXP,
  isThemeUnlocked,
  crossThemeMasteryBonus,
  calculateDamage,
  tournamentOpponentPower,
  isExpectedLoss,
} from "../core/combat.js";
import { createControllingVariables, VariableKind, trainVariable } from "../core/variables.js";

describe("theme cycling", () => {
  it("cycles through all four themes in order", () => {
    expect(nextThemeInCycle(CombatTheme.Unarmed)).toBe(CombatTheme.Armed);
    expect(nextThemeInCycle(CombatTheme.Armed)).toBe(CombatTheme.Ranged);
    expect(nextThemeInCycle(CombatTheme.Ranged)).toBe(CombatTheme.Energy);
    expect(nextThemeInCycle(CombatTheme.Energy)).toBe(CombatTheme.Unarmed);
  });

  it("THEME_ORDER has exactly 4 themes", () => {
    expect(THEME_ORDER).toHaveLength(4);
  });
});

describe("mastery XP", () => {
  it("level 0 requires 0 XP", () => {
    expect(masteryXPRequired(0)).toBe(0);
  });

  it("matches design doc examples", () => {
    expect(masteryXPRequired(1)).toBe(100);
    expect(masteryXPRequired(10)).toBe(Math.floor(100 * Math.pow(10, 1.5)));
    expect(masteryXPRequired(100)).toBe(Math.floor(100 * Math.pow(100, 1.5)));
  });

  it("is monotonically increasing", () => {
    for (let i = 1; i < 100; i++) {
      expect(masteryXPRequired(i + 1)).toBeGreaterThan(masteryXPRequired(i));
    }
  });
});

describe("mastery leveling", () => {
  it("starts at level 0 with 0 XP for all themes", () => {
    const m = createMasteryState();
    expect(m[CombatTheme.Unarmed].level).toBe(0);
    expect(m[CombatTheme.Unarmed].xp).toBe(0);
  });

  it("awards XP and levels up", () => {
    const m = createMasteryState();
    // Level 1 requires 100 XP
    const gained = awardMasteryXP(m, CombatTheme.Unarmed, 100);
    expect(gained).toBe(1);
    expect(m[CombatTheme.Unarmed].level).toBe(1);
  });

  it("carries over excess XP", () => {
    const m = createMasteryState();
    awardMasteryXP(m, CombatTheme.Unarmed, 150);
    expect(m[CombatTheme.Unarmed].level).toBe(1);
    expect(m[CombatTheme.Unarmed].xp).toBe(50); // 150 - 100
  });

  it("can gain multiple levels at once", () => {
    const m = createMasteryState();
    // Level 1 needs 100, level 2 needs floor(100 * 2^1.5) = 282
    const gained = awardMasteryXP(m, CombatTheme.Unarmed, 500);
    expect(gained).toBeGreaterThanOrEqual(2);
    expect(m[CombatTheme.Unarmed].level).toBeGreaterThanOrEqual(2);
  });

  it("caps at level 100", () => {
    const m = createMasteryState();
    awardMasteryXP(m, CombatTheme.Unarmed, 999_999_999);
    expect(m[CombatTheme.Unarmed].level).toBe(100);
  });

  it("ignores negative XP", () => {
    const m = createMasteryState();
    const gained = awardMasteryXP(m, CombatTheme.Unarmed, -100);
    expect(gained).toBe(0);
  });
});

describe("theme unlock", () => {
  it("Unarmed is always unlocked", () => {
    const m = createMasteryState();
    expect(isThemeUnlocked(m, CombatTheme.Unarmed)).toBe(true);
  });

  it("Armed requires Unarmed mastery >= 10", () => {
    const m = createMasteryState();
    expect(isThemeUnlocked(m, CombatTheme.Armed)).toBe(false);
    // Grant enough XP for level 10
    awardMasteryXP(m, CombatTheme.Unarmed, 999_999);
    expect(m[CombatTheme.Unarmed].level).toBeGreaterThanOrEqual(10);
    expect(isThemeUnlocked(m, CombatTheme.Armed)).toBe(true);
  });

  it("Ranged requires Armed mastery >= 10", () => {
    const m = createMasteryState();
    expect(isThemeUnlocked(m, CombatTheme.Ranged)).toBe(false);
    awardMasteryXP(m, CombatTheme.Armed, 999_999);
    expect(isThemeUnlocked(m, CombatTheme.Ranged)).toBe(true);
  });

  it("Energy requires Ranged mastery >= 10", () => {
    const m = createMasteryState();
    expect(isThemeUnlocked(m, CombatTheme.Energy)).toBe(false);
    awardMasteryXP(m, CombatTheme.Ranged, 999_999);
    expect(isThemeUnlocked(m, CombatTheme.Energy)).toBe(true);
  });
});

describe("crossThemeMasteryBonus", () => {
  it("returns 0 with fewer than 2 themes at 50+", () => {
    const m = createMasteryState();
    expect(crossThemeMasteryBonus(m)).toBe(0);
    awardMasteryXP(m, CombatTheme.Unarmed, 999_999_999);
    expect(crossThemeMasteryBonus(m)).toBe(0); // only 1 at 50+
  });

  it("returns 0.05 with 2 themes at 50+", () => {
    const m = createMasteryState();
    awardMasteryXP(m, CombatTheme.Unarmed, 999_999_999);
    awardMasteryXP(m, CombatTheme.Armed, 999_999_999);
    expect(crossThemeMasteryBonus(m)).toBe(0.05);
  });

  it("returns 0.20 with all 4 themes at 50+", () => {
    const m = createMasteryState();
    for (const theme of THEME_ORDER) {
      awardMasteryXP(m, theme, 999_999_999);
    }
    expect(crossThemeMasteryBonus(m)).toBe(0.2);
  });
});

describe("calculateDamage", () => {
  it("returns baseDamage when powerLevel=0 and no variable scaling", () => {
    const vars = createControllingVariables();
    const mastery = createMasteryState();
    const dmg = calculateDamage({
      baseDamage: 100,
      powerLevel: 0,
      theme: CombatTheme.Unarmed,
      variables: vars,
      mastery,
    });
    // 100 * (1 + 0/100) * 1.0 * 1.0 * 1.0 = 100
    expect(dmg).toBe(100);
  });

  it("power level multiplies damage", () => {
    const vars = createControllingVariables();
    const mastery = createMasteryState();
    const dmg = calculateDamage({
      baseDamage: 100,
      powerLevel: 100,
      theme: CombatTheme.Unarmed,
      variables: vars,
      mastery,
    });
    // 100 * (1 + 100/100) = 100 * 2 = 200
    expect(dmg).toBe(200);
  });

  it("variable scaling adds damage", () => {
    const vars = createControllingVariables();
    trainVariable(vars, VariableKind.Strength, 50);
    const mastery = createMasteryState();
    const dmg = calculateDamage({
      baseDamage: 100,
      powerLevel: 0,
      theme: CombatTheme.Unarmed,
      variables: vars,
      mastery,
    });
    // Strength contributes 0.02 per point to unarmed = 1.0 scaling
    // 100 * 1.0 * 1.0 * (1 + 1.0) * 1.0 = 200
    expect(dmg).toBe(200);
  });
});

describe("tournament", () => {
  it("opponent power scales with victories", () => {
    const base = tournamentOpponentPower(100, 0, 1);
    expect(base).toBe(100);

    const after10 = tournamentOpponentPower(100, 10, 1);
    expect(after10).toBeCloseTo(100 * Math.pow(1.05, 10));
    expect(after10).toBeGreaterThan(base);
  });

  it("opponent power scales with environment tier", () => {
    const t1 = tournamentOpponentPower(100, 5, 1);
    const t3 = tournamentOpponentPower(100, 5, 3);
    expect(t3).toBe(t1 * 3);
  });

  it("isExpectedLoss when opponent > player * 1.2", () => {
    expect(isExpectedLoss(130, 100)).toBe(true);
    expect(isExpectedLoss(120, 100)).toBe(false);
    expect(isExpectedLoss(119, 100)).toBe(false);
  });
});
