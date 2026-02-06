/**
 * Combat Encounter System
 *
 * Triggered when the player character touches an opponent on the map.
 * Visual presentation: Pokemon/NGU Idle style — opponent faces viewer,
 * player's back faces viewer. Same framing supports cutscenes.
 *
 * This module handles the data/logic layer. The Godot scene tree will
 * handle the visual presentation (camera, sprites, UI overlay).
 */

import { CombatTheme } from "./combat.js";

// ---------------------------------------------------------------------------
// Opponent definitions
// ---------------------------------------------------------------------------

export interface LootTableEntry {
  itemId: string;
  /** Drop chance 0–1. */
  dropRate: number;
  /** Min quantity when dropped. */
  minQty: number;
  /** Max quantity when dropped. */
  maxQty: number;
}

export interface OpponentDefinition {
  id: string;
  name: string;
  /** Base power level of this opponent type. */
  basePower: number;
  /** Base HP. */
  baseHP: number;
  /** Base damage per attack. */
  baseDamage: number;
  /** Attack speed in seconds between attacks. */
  attackSpeed: number;
  /** Gold dropped on defeat (base, before modifiers). */
  goldReward: number;
  /** Power Level XP awarded on defeat. */
  plReward: number;
  /** Mastery XP awarded on defeat. */
  masteryXPReward: number;
  /** Loot table for item drops. */
  lootTable: LootTableEntry[];
  /** Environment this opponent belongs to. */
  environmentId: string;
  /** Whether this is a boss opponent. */
  isBoss: boolean;
}

// ---------------------------------------------------------------------------
// Encounter state machine
// ---------------------------------------------------------------------------

export enum EncounterPhase {
  /** Scene is loading / transition animation. */
  Intro = "intro",
  /** Active combat — turns are being exchanged. */
  Active = "active",
  /** Player won — loot/rewards being displayed. */
  Victory = "victory",
  /** Player lost — defeat screen. */
  Defeat = "defeat",
  /** Encounter is over, returning to map. */
  Exiting = "exiting",
}

export interface EncounterState {
  phase: EncounterPhase;
  opponent: OpponentDefinition;

  /** Player's current HP for this encounter. */
  playerHP: number;
  /** Player's max HP for this encounter. */
  playerMaxHP: number;

  /** Opponent's remaining HP. */
  opponentHP: number;

  /** The combat theme the player is using. */
  playerTheme: CombatTheme;

  /** Running damage total dealt by player (for stats). */
  playerDamageDealt: number;
  /** Running damage total dealt by opponent (for stats). */
  opponentDamageDealt: number;

  /** Accumulated time in this encounter (seconds). */
  elapsedTime: number;

  /** Loot rolls determined at victory. */
  lootDrops: { itemId: string; quantity: number }[];
}

export interface StartEncounterParams {
  opponent: OpponentDefinition;
  playerHP: number;
  playerMaxHP: number;
  playerTheme: CombatTheme;
}

export function startEncounter(params: StartEncounterParams): EncounterState {
  return {
    phase: EncounterPhase.Intro,
    opponent: params.opponent,
    playerHP: params.playerHP,
    playerMaxHP: params.playerMaxHP,
    opponentHP: params.opponent.baseHP,
    playerTheme: params.playerTheme,
    playerDamageDealt: 0,
    opponentDamageDealt: 0,
    elapsedTime: 0,
    lootDrops: [],
  };
}

export function beginCombat(state: EncounterState): void {
  state.phase = EncounterPhase.Active;
}

/**
 * Apply damage to the opponent. Returns remaining HP.
 */
export function damageOpponent(state: EncounterState, damage: number): number {
  if (damage <= 0) return state.opponentHP;
  state.opponentHP = Math.max(0, state.opponentHP - damage);
  state.playerDamageDealt += damage;
  return state.opponentHP;
}

/**
 * Apply damage to the player. Returns remaining HP.
 */
export function damagePlayer(state: EncounterState, damage: number): number {
  if (damage <= 0) return state.playerHP;
  state.playerHP = Math.max(0, state.playerHP - damage);
  state.opponentDamageDealt += damage;
  return state.playerHP;
}

/**
 * Check if the encounter should resolve (someone reached 0 HP).
 * Transitions to Victory or Defeat phase.
 */
export function checkEncounterResolution(state: EncounterState): EncounterPhase {
  if (state.phase !== EncounterPhase.Active) return state.phase;

  if (state.opponentHP <= 0) {
    state.phase = EncounterPhase.Victory;
    state.lootDrops = rollLoot(state.opponent.lootTable);
  } else if (state.playerHP <= 0) {
    state.phase = EncounterPhase.Defeat;
  }
  return state.phase;
}

/**
 * Roll loot from the opponent's loot table.
 * Uses simple probability — each entry is rolled independently.
 */
export function rollLoot(
  lootTable: LootTableEntry[],
  rng: () => number = Math.random,
): { itemId: string; quantity: number }[] {
  const drops: { itemId: string; quantity: number }[] = [];
  for (const entry of lootTable) {
    if (rng() <= entry.dropRate) {
      const quantity =
        entry.minQty === entry.maxQty
          ? entry.minQty
          : entry.minQty +
            Math.floor(rng() * (entry.maxQty - entry.minQty + 1));
      drops.push({ itemId: entry.itemId, quantity });
    }
  }
  return drops;
}

export function exitEncounter(state: EncounterState): void {
  state.phase = EncounterPhase.Exiting;
}

// ---------------------------------------------------------------------------
// Encounter rewards calculation
// ---------------------------------------------------------------------------

export interface EncounterRewards {
  gold: number;
  powerLevelGain: number;
  masteryXP: number;
  loot: { itemId: string; quantity: number }[];
}

/**
 * Calculate the rewards from a victorious encounter.
 * Only meaningful when phase === Victory.
 */
export function calculateEncounterRewards(
  state: EncounterState,
): EncounterRewards {
  if (state.phase !== EncounterPhase.Victory) {
    return { gold: 0, powerLevelGain: 0, masteryXP: 0, loot: [] };
  }
  return {
    gold: state.opponent.goldReward,
    powerLevelGain: state.opponent.plReward,
    masteryXP: state.opponent.masteryXPReward,
    loot: state.lootDrops,
  };
}
