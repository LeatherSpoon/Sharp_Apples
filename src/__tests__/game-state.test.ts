import { describe, it, expect } from "vitest";
import {
  createGameState,
  tickManagers,
  tickMovement,
  spendPedometerForUpgrade,
  requiredCombatTheme,
  getEffectivePowerLevel,
  performMasterReset,
  tick,
} from "../core/game-state.js";
import { CombatTheme } from "../core/combat.js";
import { VariableKind } from "../core/variables.js";
import { TaskManagerType } from "../core/managers.js";
import { BASE_SPEED, PEDOMETER_SPEED_CAP_PERCENT } from "../core/speed.js";
import { earnPowerLevel, buyPermanentUpgrade } from "../core/currencies.js";

describe("createGameState", () => {
  it("initializes with sensible defaults", () => {
    const state = createGameState();
    expect(state.powerLevel.current).toBe(1);
    expect(state.powerLevel.permanent).toBe(0);
    expect(getEffectivePowerLevel(state)).toBe(1);
    expect(state.pedometer.count).toBe(0);
    expect(state.gold.amount).toBe(0);
    expect(state.activeCombatTheme).toBe(CombatTheme.Unarmed);
    expect(state.totalPlayTimeSeconds).toBe(0);
  });
});

describe("tickManagers", () => {
  it("does nothing with no managers", () => {
    const state = createGameState();
    const gains = tickManagers(state, 3600); // 1 hour
    expect(gains[VariableKind.Strength]).toBe(0);
  });

  it("passively trains Strength via Mining Foreman", () => {
    const state = createGameState();
    state.managers.taskManagers[TaskManagerType.MiningForeman] = 1;
    const gains = tickManagers(state, 3600); // 1 hour
    // 1 foreman = 50% efficiency, casual rate 10/hr → 5/hr
    expect(gains[VariableKind.Strength]).toBeCloseTo(5);
    expect(state.variables[VariableKind.Strength]).toBeCloseTo(5);
  });

  it("scales with elapsed time", () => {
    const state = createGameState();
    state.managers.taskManagers[TaskManagerType.RunningCoach] = 1;
    const gains = tickManagers(state, 1800); // 30 minutes
    // 5/hr for 30 min = 2.5
    expect(gains[VariableKind.Endurance]).toBeCloseTo(2.5);
  });
});

describe("tickMovement", () => {
  it("adds steps based on current speed", () => {
    const state = createGameState();
    const steps = tickMovement(state, 1); // 1 second
    expect(steps).toBe(BASE_SPEED); // 100 units/s at start
    expect(state.pedometer.count).toBe(BASE_SPEED);
  });

  it("faster speed means more steps", () => {
    const state = createGameState();
    state.speed.pedometerBonusPercent = 100; // 200% speed
    const steps = tickMovement(state, 1);
    expect(steps).toBe(200);
  });
});

describe("spendPedometerForUpgrade", () => {
  it("applies speed bonus when not capped", () => {
    const state = createGameState();
    // Accumulate 10k steps
    tickMovement(state, 100);
    const result = spendPedometerForUpgrade(state);

    expect(result.stepsSpent).toBeGreaterThan(0);
    expect(result.speedBonusApplied).toBeGreaterThan(0);
    expect(result.powerLevelBonusApplied).toBe(0);
    expect(state.pedometer.count).toBe(0);
    expect(state.speed.pedometerBonusPercent).toBeGreaterThan(0);
  });

  it("awards permanent power level when speed is capped", () => {
    const state = createGameState();
    state.speed.pedometerBonusPercent = PEDOMETER_SPEED_CAP_PERCENT;
    // Accumulate some steps
    tickMovement(state, 100);
    const result = spendPedometerForUpgrade(state);

    expect(result.speedBonusApplied).toBe(0);
    expect(result.powerLevelBonusApplied).toBeGreaterThan(0);
    // Goes to permanent PL, not current
    expect(state.powerLevel.permanent).toBeGreaterThan(0);
  });
});

describe("requiredCombatTheme", () => {
  it("returns the theme of the current environment", () => {
    const state = createGameState();
    expect(requiredCombatTheme(state)).toBe(CombatTheme.Unarmed);
  });
});

describe("getEffectivePowerLevel", () => {
  it("combines permanent and current PL", () => {
    const state = createGameState();
    earnPowerLevel(state.powerLevel, 49); // current = 50
    state.powerLevel.permanent = 100;
    expect(getEffectivePowerLevel(state)).toBe(150);
  });
});

describe("performMasterReset", () => {
  it("resets current PL to 1, preserves permanent, advances environment", () => {
    const state = createGameState();
    earnPowerLevel(state.powerLevel, 499); // current = 500
    buyPermanentUpgrade(state.powerLevel, 200, 20); // perm = 20, current = 300

    const result = performMasterReset(state);

    expect(result.currentPLLost).toBe(300); // the current PL that was wiped
    expect(state.powerLevel.current).toBe(1);
    expect(state.powerLevel.permanent).toBe(20); // preserved
    expect(getEffectivePowerLevel(state)).toBe(21);
    expect(result.newEnvironmentName).toBe("Iron Fortress");
    expect(result.newTheme).toBe(CombatTheme.Armed);
    expect(state.activeCombatTheme).toBe(CombatTheme.Armed);
  });

  it("returns null when no more authored environments", () => {
    const state = createGameState();
    // Advance through all environments
    for (let i = 0; i < 4; i++) {
      performMasterReset(state);
    }
    const result = performMasterReset(state);
    expect(result.newEnvironmentName).toBeNull();
    expect(result.newTheme).toBeNull();
  });

  it("preserves all non-PL state across resets", () => {
    const state = createGameState();
    state.variables[VariableKind.Strength] = 50;
    state.gold.amount = 5000;
    state.speed.pedometerBonusPercent = 100;

    performMasterReset(state);

    // These should all survive the master reset
    expect(state.variables[VariableKind.Strength]).toBe(50);
    expect(state.gold.amount).toBe(5000);
    expect(state.speed.pedometerBonusPercent).toBe(100);
  });

  it("each reset makes the player start with a higher baseline", () => {
    const state = createGameState();

    // Cycle 1: earn 100, buy 10 perm, reset
    earnPowerLevel(state.powerLevel, 99);
    buyPermanentUpgrade(state.powerLevel, 50, 10);
    performMasterReset(state);
    const baselineAfter1 = getEffectivePowerLevel(state);

    // Cycle 2: earn 200, buy 20 perm, reset
    earnPowerLevel(state.powerLevel, 199);
    buyPermanentUpgrade(state.powerLevel, 100, 20);
    performMasterReset(state);
    const baselineAfter2 = getEffectivePowerLevel(state);

    expect(baselineAfter2).toBeGreaterThan(baselineAfter1);
    expect(state.powerLevel.permanent).toBe(30); // 10 + 20
    expect(state.powerLevel.timesReset).toBe(2);
  });
});

describe("tick", () => {
  it("increments play time", () => {
    const state = createGameState();
    tick(state, 5, false);
    expect(state.totalPlayTimeSeconds).toBe(5);
  });

  it("does not add steps when not moving", () => {
    const state = createGameState();
    tick(state, 10, false);
    expect(state.pedometer.count).toBe(0);
  });

  it("adds steps when moving", () => {
    const state = createGameState();
    tick(state, 10, true);
    expect(state.pedometer.count).toBeGreaterThan(0);
  });

  it("processes manager gains regardless of movement", () => {
    const state = createGameState();
    state.managers.taskManagers[TaskManagerType.MiningForeman] = 1;
    tick(state, 3600, false);
    expect(state.variables[VariableKind.Strength]).toBeGreaterThan(0);
  });
});
