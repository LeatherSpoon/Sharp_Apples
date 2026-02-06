import { describe, it, expect } from "vitest";
import {
  EncounterPhase,
  startEncounter,
  beginCombat,
  damageOpponent,
  damagePlayer,
  checkEncounterResolution,
  rollLoot,
  calculateEncounterRewards,
  exitEncounter,
  type OpponentDefinition,
} from "../core/encounter.js";
import { CombatTheme } from "../core/combat.js";

const makeOpponent = (overrides: Partial<OpponentDefinition> = {}): OpponentDefinition => ({
  id: "test_slime",
  name: "Test Slime",
  basePower: 10,
  baseHP: 50,
  baseDamage: 5,
  attackSpeed: 1.0,
  goldReward: 20,
  plReward: 10,
  masteryXPReward: 5,
  lootTable: [],
  environmentId: "forest_dojo",
  isBoss: false,
  ...overrides,
});

describe("startEncounter", () => {
  it("creates an encounter in Intro phase", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    expect(state.phase).toBe(EncounterPhase.Intro);
    expect(state.opponentHP).toBe(50);
    expect(state.playerHP).toBe(100);
    expect(state.playerDamageDealt).toBe(0);
    expect(state.opponentDamageDealt).toBe(0);
    expect(state.elapsedTime).toBe(0);
    expect(state.lootDrops).toHaveLength(0);
  });
});

describe("beginCombat", () => {
  it("transitions from Intro to Active", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);
    expect(state.phase).toBe(EncounterPhase.Active);
  });
});

describe("damageOpponent", () => {
  it("reduces opponent HP and tracks player damage dealt", () => {
    const state = startEncounter({
      opponent: makeOpponent({ baseHP: 100 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);

    const remaining = damageOpponent(state, 30);
    expect(remaining).toBe(70);
    expect(state.opponentHP).toBe(70);
    expect(state.playerDamageDealt).toBe(30);
  });

  it("clamps opponent HP at 0", () => {
    const state = startEncounter({
      opponent: makeOpponent({ baseHP: 20 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);

    damageOpponent(state, 50);
    expect(state.opponentHP).toBe(0);
  });

  it("ignores non-positive damage", () => {
    const state = startEncounter({
      opponent: makeOpponent({ baseHP: 50 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);

    damageOpponent(state, 0);
    expect(state.opponentHP).toBe(50);
    damageOpponent(state, -10);
    expect(state.opponentHP).toBe(50);
  });
});

describe("damagePlayer", () => {
  it("reduces player HP and tracks opponent damage dealt", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);

    const remaining = damagePlayer(state, 25);
    expect(remaining).toBe(75);
    expect(state.playerHP).toBe(75);
    expect(state.opponentDamageDealt).toBe(25);
  });

  it("clamps player HP at 0", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 30,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);

    damagePlayer(state, 50);
    expect(state.playerHP).toBe(0);
  });
});

describe("checkEncounterResolution", () => {
  it("transitions to Victory when opponent HP reaches 0", () => {
    const state = startEncounter({
      opponent: makeOpponent({ baseHP: 30 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);
    damageOpponent(state, 30);

    const phase = checkEncounterResolution(state);
    expect(phase).toBe(EncounterPhase.Victory);
    expect(state.phase).toBe(EncounterPhase.Victory);
  });

  it("transitions to Defeat when player HP reaches 0", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 20,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);
    damagePlayer(state, 20);

    const phase = checkEncounterResolution(state);
    expect(phase).toBe(EncounterPhase.Defeat);
  });

  it("does nothing when both still alive", () => {
    const state = startEncounter({
      opponent: makeOpponent({ baseHP: 100 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);
    damageOpponent(state, 10);
    damagePlayer(state, 10);

    expect(checkEncounterResolution(state)).toBe(EncounterPhase.Active);
  });

  it("does not resolve if not in Active phase", () => {
    const state = startEncounter({
      opponent: makeOpponent({ baseHP: 1 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    // Still in Intro phase
    expect(checkEncounterResolution(state)).toBe(EncounterPhase.Intro);
  });
});

describe("rollLoot", () => {
  it("returns empty array for empty loot table", () => {
    expect(rollLoot([])).toEqual([]);
  });

  it("always drops items with 100% drop rate", () => {
    const table = [{ itemId: "gold_ore", dropRate: 1.0, minQty: 1, maxQty: 1 }];
    const drops = rollLoot(table, () => 0.5);
    expect(drops).toEqual([{ itemId: "gold_ore", quantity: 1 }]);
  });

  it("never drops items with 0% drop rate", () => {
    const table = [{ itemId: "gold_ore", dropRate: 0, minQty: 1, maxQty: 1 }];
    const drops = rollLoot(table, () => 0.5);
    expect(drops).toEqual([]);
  });

  it("rolls quantity between min and max", () => {
    const table = [{ itemId: "stone", dropRate: 1.0, minQty: 1, maxQty: 5 }];
    // rng() returns: first call 0.0 (for drop check), second call 0.99 (for qty)
    let callCount = 0;
    const drops = rollLoot(table, () => {
      callCount++;
      return callCount === 1 ? 0.0 : 0.99;
    });
    expect(drops).toHaveLength(1);
    expect(drops[0].quantity).toBeGreaterThanOrEqual(1);
    expect(drops[0].quantity).toBeLessThanOrEqual(5);
  });

  it("handles fixed quantity (min === max)", () => {
    const table = [{ itemId: "key", dropRate: 1.0, minQty: 3, maxQty: 3 }];
    const drops = rollLoot(table, () => 0.5);
    expect(drops).toEqual([{ itemId: "key", quantity: 3 }]);
  });
});

describe("calculateEncounterRewards", () => {
  it("returns rewards on Victory", () => {
    const state = startEncounter({
      opponent: makeOpponent({ goldReward: 50, plReward: 25, masteryXPReward: 10 }),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);
    damageOpponent(state, 50);
    checkEncounterResolution(state);

    const rewards = calculateEncounterRewards(state);
    expect(rewards.gold).toBe(50);
    expect(rewards.powerLevelGain).toBe(25);
    expect(rewards.masteryXP).toBe(10);
  });

  it("returns zero rewards on non-Victory phase", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);

    const rewards = calculateEncounterRewards(state);
    expect(rewards.gold).toBe(0);
    expect(rewards.powerLevelGain).toBe(0);
    expect(rewards.masteryXP).toBe(0);
    expect(rewards.loot).toEqual([]);
  });
});

describe("exitEncounter", () => {
  it("transitions to Exiting phase", () => {
    const state = startEncounter({
      opponent: makeOpponent(),
      playerHP: 100,
      playerMaxHP: 100,
      playerTheme: CombatTheme.Unarmed,
    });
    beginCombat(state);
    exitEncounter(state);
    expect(state.phase).toBe(EncounterPhase.Exiting);
  });
});
