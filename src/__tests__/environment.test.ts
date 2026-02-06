import { describe, it, expect } from "vitest";
import {
  ENVIRONMENTS,
  EnvironmentPhase,
  createProgressionState,
  currentEnvironment,
  currentCombatTheme,
  advanceEnvironment,
  recordTournamentVictory,
  recordTournamentDefeat,
} from "../core/environment.js";
import { CombatTheme } from "../core/combat.js";

describe("environment definitions", () => {
  it("has at least 5 authored environments", () => {
    expect(ENVIRONMENTS.length).toBeGreaterThanOrEqual(5);
  });

  it("first environment is Forest Dojo with Unarmed theme", () => {
    const first = ENVIRONMENTS[0];
    expect(first.name).toBe("Forest Dojo");
    expect(first.combatTheme).toBe(CombatTheme.Unarmed);
    expect(first.masterName).toBe("Master Chen");
  });

  it("themes cycle across environments", () => {
    const themes = ENVIRONMENTS.map((e) => e.combatTheme);
    expect(themes[0]).toBe(CombatTheme.Unarmed);
    expect(themes[1]).toBe(CombatTheme.Armed);
    expect(themes[2]).toBe(CombatTheme.Ranged);
    expect(themes[3]).toBe(CombatTheme.Energy);
    expect(themes[4]).toBe(CombatTheme.Unarmed); // cycle repeats
  });
});

describe("progression state", () => {
  it("starts in first environment, training phase", () => {
    const state = createProgressionState();
    expect(state.currentEnvironmentIndex).toBe(0);
    expect(currentEnvironment(state).name).toBe("Forest Dojo");
    expect(currentCombatTheme(state)).toBe(CombatTheme.Unarmed);
    expect(state.unlockedEnvironments).toContain("forest_dojo");
  });

  it("environment progress starts in training phase", () => {
    const state = createProgressionState();
    const progress = state.environmentProgress["forest_dojo"];
    expect(progress.phase).toBe(EnvironmentPhase.Training);
    expect(progress.bossDefeated).toBe(false);
    expect(progress.tournamentVictories).toBe(0);
  });
});

describe("advanceEnvironment", () => {
  it("moves to the next environment", () => {
    const state = createProgressionState();
    const next = advanceEnvironment(state);
    expect(next).not.toBeNull();
    expect(next!.name).toBe("Iron Fortress");
    expect(state.currentEnvironmentIndex).toBe(1);
    expect(state.unlockedEnvironments).toContain("iron_fortress");
  });

  it("creates progress entry for new environment", () => {
    const state = createProgressionState();
    advanceEnvironment(state);
    const progress = state.environmentProgress["iron_fortress"];
    expect(progress).toBeDefined();
    expect(progress.phase).toBe(EnvironmentPhase.Training);
  });

  it("returns null when no more authored environments", () => {
    const state = createProgressionState();
    for (let i = 0; i < ENVIRONMENTS.length - 1; i++) {
      advanceEnvironment(state);
    }
    const result = advanceEnvironment(state);
    expect(result).toBeNull();
  });

  it("tracks theme cycle completion", () => {
    const state = createProgressionState();
    expect(state.themeCyclesCompleted).toBe(0);
    // Advance through first 4 environments (Unarmed→Armed→Ranged→Energy)
    advanceEnvironment(state); // → Iron Fortress (Armed)
    advanceEnvironment(state); // → Wind Valley (Ranged)
    advanceEnvironment(state); // → Crystal Spire (Energy)
    expect(state.themeCyclesCompleted).toBe(0);
    advanceEnvironment(state); // → Desert Temple (Unarmed again = cycle complete)
    expect(state.themeCyclesCompleted).toBe(1);
  });
});

describe("tournament tracking", () => {
  it("records victories", () => {
    const state = createProgressionState();
    recordTournamentVictory(state);
    recordTournamentVictory(state);
    const progress = state.environmentProgress["forest_dojo"];
    expect(progress.tournamentVictories).toBe(2);
  });

  it("records defeat", () => {
    const state = createProgressionState();
    recordTournamentDefeat(state);
    const progress = state.environmentProgress["forest_dojo"];
    expect(progress.tournamentDefeated).toBe(true);
  });
});
