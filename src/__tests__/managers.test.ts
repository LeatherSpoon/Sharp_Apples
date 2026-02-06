import { describe, it, expect } from "vitest";
import {
  TaskManagerType,
  ManagerCategory,
  createManagerState,
  taskManagerCost,
  totalTaskManagerInvestment,
  canUnlockDepartmentManager,
  canUnlockVP,
  canUnlockCEO,
  stackEfficiency,
  automationEfficiency,
  passiveGainsPerHour,
  performPrestige,
  prestigeMultiplier,
  TASK_MANAGER_BASE_COST,
  CASUAL_ACTIVE_RATE_PER_HOUR,
} from "../core/managers.js";

describe("cost calculations", () => {
  it("first task manager costs base cost", () => {
    expect(taskManagerCost(0)).toBe(TASK_MANAGER_BASE_COST);
  });

  it("cost doubles each time", () => {
    expect(taskManagerCost(0)).toBe(1_000);
    expect(taskManagerCost(1)).toBe(2_000);
    expect(taskManagerCost(2)).toBe(4_000);
    expect(taskManagerCost(3)).toBe(8_000);
  });

  it("total investment matches design doc table", () => {
    expect(totalTaskManagerInvestment(1)).toBe(1_000);
    expect(totalTaskManagerInvestment(2)).toBe(3_000);
    expect(totalTaskManagerInvestment(3)).toBe(7_000);
    expect(totalTaskManagerInvestment(4)).toBe(15_000);
    expect(totalTaskManagerInvestment(5)).toBe(31_000);
  });

  it("total investment for 0 is 0", () => {
    expect(totalTaskManagerInvestment(0)).toBe(0);
  });
});

describe("stackEfficiency", () => {
  it("0 managers → 0%", () => {
    expect(stackEfficiency(0)).toBe(0);
  });

  it("1 manager → 50%", () => {
    expect(stackEfficiency(1)).toBe(0.5);
  });

  it("2 managers → 75%", () => {
    expect(stackEfficiency(2)).toBe(0.75);
  });

  it("3 managers → 87.5%", () => {
    expect(stackEfficiency(3)).toBe(0.875);
  });

  it("approaches but never reaches 100%", () => {
    expect(stackEfficiency(20)).toBeLessThan(1.0);
    expect(stackEfficiency(20)).toBeGreaterThan(0.999);
  });
});

describe("unlock checks", () => {
  it("department manager needs 2+ task managers in category", () => {
    const state = createManagerState();
    expect(canUnlockDepartmentManager(state, ManagerCategory.Physical)).toBe(false);

    state.taskManagers[TaskManagerType.MiningForeman] = 1;
    state.taskManagers[TaskManagerType.RunningCoach] = 1;
    expect(canUnlockDepartmentManager(state, ManagerCategory.Physical)).toBe(true);
  });

  it("VP needs both department managers", () => {
    const state = createManagerState();
    expect(canUnlockVP(state)).toBe(false);

    state.physicalDirector = true;
    expect(canUnlockVP(state)).toBe(false);

    state.mentalDirector = true;
    expect(canUnlockVP(state)).toBe(true);
  });

  it("CEO needs VP + completed theme cycle", () => {
    const state = createManagerState();
    state.vpOfTraining = true;
    expect(canUnlockCEO(state, false)).toBe(false);
    expect(canUnlockCEO(state, true)).toBe(true);
  });
});

describe("automationEfficiency", () => {
  it("returns 0 with no task managers", () => {
    const state = createManagerState();
    expect(automationEfficiency(state, TaskManagerType.MiningForeman)).toBe(0);
  });

  it("1 foreman = 50%", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MiningForeman] = 1;
    expect(automationEfficiency(state, TaskManagerType.MiningForeman)).toBeCloseTo(0.5);
  });

  it("department manager adds 25%", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MiningForeman] = 1;
    state.physicalDirector = true;
    // 0.5 * 1.25 = 0.625
    expect(automationEfficiency(state, TaskManagerType.MiningForeman)).toBeCloseTo(0.625);
  });

  it("VP adds 50% on top of department", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MiningForeman] = 1;
    state.physicalDirector = true;
    state.vpOfTraining = true;
    // 0.5 * 1.25 * 1.5 = 0.9375
    expect(automationEfficiency(state, TaskManagerType.MiningForeman)).toBeCloseTo(0.9375);
  });

  it("caps at 100% even with high multipliers", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MiningForeman] = 5;
    state.physicalDirector = true;
    state.vpOfTraining = true;
    state.prestigeLevel = 5;
    // Would be well over 100% uncapped
    expect(automationEfficiency(state, TaskManagerType.MiningForeman)).toBe(1.0);
  });

  it("mental category uses mental director", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MeditationGuide] = 1;
    state.mentalDirector = true;
    expect(automationEfficiency(state, TaskManagerType.MeditationGuide)).toBeCloseTo(0.625);
  });
});

describe("passiveGainsPerHour", () => {
  it("returns gains based on automation efficiency", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MiningForeman] = 1;
    // 50% efficiency * 10/hour active rate = 5/hour
    expect(passiveGainsPerHour(state, TaskManagerType.MiningForeman)).toBeCloseTo(5);
  });
});

describe("prestige", () => {
  it("increments prestige level and resets managers", () => {
    const state = createManagerState();
    state.taskManagers[TaskManagerType.MiningForeman] = 3;
    state.physicalDirector = true;
    state.vpOfTraining = true;
    state.ceo = true;

    const result = performPrestige(state);
    expect(result.newPrestigeLevel).toBe(1);
    expect(result.multiplier).toBeCloseTo(1.1);

    // All managers reset
    expect(state.taskManagers[TaskManagerType.MiningForeman]).toBe(0);
    expect(state.physicalDirector).toBe(false);
    expect(state.vpOfTraining).toBe(false);
    expect(state.ceo).toBe(false);
  });

  it("prestige multiplier formula matches design doc", () => {
    expect(prestigeMultiplier(0)).toBe(1.0);
    expect(prestigeMultiplier(1)).toBeCloseTo(1.1);
    expect(prestigeMultiplier(5)).toBeCloseTo(1.5);
    expect(prestigeMultiplier(10)).toBeCloseTo(2.0);
  });

  it("can prestige multiple times", () => {
    const state = createManagerState();
    performPrestige(state);
    expect(state.prestigeLevel).toBe(1);
    performPrestige(state);
    expect(state.prestigeLevel).toBe(2);
    expect(prestigeMultiplier(state.prestigeLevel)).toBeCloseTo(1.2);
  });
});
