/**
 * Tool & Gadget Slot System (placeholder architecture)
 *
 * Tools modify how laborious activities work — each activity slot can hold
 * one tool that boosts efficiency, unlocks new resource types, or gates
 * dungeon content (e.g. a pickaxe tier gates mining nodes in caves).
 *
 * Gadgets are passive equippables that provide misc. bonuses (crit, speed,
 * loot quality, etc.). Limited gadget slots expand through progression.
 *
 * This module defines the data model and slot management. Actual tool
 * effects will be implemented in the Godot layer and wired into the
 * corresponding activity/combat systems.
 */

import { TrainingActivity } from "./variables.js";

// ---------------------------------------------------------------------------
// Tool tiers & definitions
// ---------------------------------------------------------------------------

export enum ToolTier {
  None = 0,
  Basic = 1,
  Iron = 2,
  Steel = 3,
  Mythril = 4,
  Legendary = 5,
}

export interface ToolDefinition {
  id: string;
  name: string;
  /** Which activity this tool applies to. */
  activity: TrainingActivity;
  /** Tool tier — higher tiers gate better dungeon nodes. */
  tier: ToolTier;
  /** Multiplier applied to the activity's training rate. */
  efficiencyMultiplier: number;
  /** Flavor text for UI. */
  description: string;
}

// ---------------------------------------------------------------------------
// Gadget definitions
// ---------------------------------------------------------------------------

export enum GadgetSlotType {
  Offensive = "offensive",
  Defensive = "defensive",
  Utility = "utility",
}

export interface GadgetEffect {
  /** Stat or bonus this gadget affects. */
  stat: string;
  /** Flat bonus added. */
  flatBonus: number;
  /** Multiplicative bonus (1.0 = no change, 1.1 = +10%). */
  percentBonus: number;
}

export interface GadgetDefinition {
  id: string;
  name: string;
  slotType: GadgetSlotType;
  effects: GadgetEffect[];
  description: string;
}

// ---------------------------------------------------------------------------
// Equipment state
// ---------------------------------------------------------------------------

export interface ToolSlots {
  /** One tool per activity. null = no tool equipped. */
  equipped: Partial<Record<TrainingActivity, ToolDefinition | null>>;
}

export interface GadgetSlots {
  /** Max number of gadget slots available (starts at 1, grows with progression). */
  maxSlots: number;
  /** Currently equipped gadgets (length <= maxSlots). */
  equipped: GadgetDefinition[];
}

export interface EquipmentState {
  tools: ToolSlots;
  gadgets: GadgetSlots;
}

export function createEquipmentState(): EquipmentState {
  return {
    tools: { equipped: {} },
    gadgets: { maxSlots: 1, equipped: [] },
  };
}

// ---------------------------------------------------------------------------
// Tool operations
// ---------------------------------------------------------------------------

/**
 * Equip a tool to its corresponding activity slot.
 * Returns the previously equipped tool (or null).
 */
export function equipTool(
  state: EquipmentState,
  tool: ToolDefinition,
): ToolDefinition | null {
  const prev = state.tools.equipped[tool.activity] ?? null;
  state.tools.equipped[tool.activity] = tool;
  return prev;
}

/**
 * Unequip the tool from a given activity slot.
 */
export function unequipTool(
  state: EquipmentState,
  activity: TrainingActivity,
): ToolDefinition | null {
  const prev = state.tools.equipped[activity] ?? null;
  state.tools.equipped[activity] = null;
  return prev;
}

/**
 * Get the currently equipped tool for an activity (or null).
 */
export function getEquippedTool(
  state: EquipmentState,
  activity: TrainingActivity,
): ToolDefinition | null {
  return state.tools.equipped[activity] ?? null;
}

/**
 * Get the tool tier for a given activity (0 if nothing equipped).
 */
export function getToolTier(
  state: EquipmentState,
  activity: TrainingActivity,
): ToolTier {
  return state.tools.equipped[activity]?.tier ?? ToolTier.None;
}

/**
 * Get the tool efficiency multiplier for a given activity (1.0 if nothing equipped).
 */
export function toolEfficiencyMultiplier(
  state: EquipmentState,
  activity: TrainingActivity,
): number {
  return state.tools.equipped[activity]?.efficiencyMultiplier ?? 1.0;
}

// ---------------------------------------------------------------------------
// Gadget operations
// ---------------------------------------------------------------------------

/**
 * Equip a gadget. Returns false if no slots available.
 */
export function equipGadget(
  state: EquipmentState,
  gadget: GadgetDefinition,
): boolean {
  if (state.gadgets.equipped.length >= state.gadgets.maxSlots) {
    return false;
  }
  state.gadgets.equipped.push(gadget);
  return true;
}

/**
 * Unequip a gadget by index. Returns the removed gadget or null.
 */
export function unequipGadget(
  state: EquipmentState,
  index: number,
): GadgetDefinition | null {
  if (index < 0 || index >= state.gadgets.equipped.length) return null;
  return state.gadgets.equipped.splice(index, 1)[0];
}

/**
 * Expand the number of available gadget slots.
 */
export function expandGadgetSlots(state: EquipmentState, additionalSlots: number): void {
  if (additionalSlots > 0) {
    state.gadgets.maxSlots += additionalSlots;
  }
}

/**
 * Aggregate all gadget effects into a single map of stat → total bonus.
 */
export function aggregateGadgetEffects(
  state: EquipmentState,
): Map<string, { flat: number; percent: number }> {
  const totals = new Map<string, { flat: number; percent: number }>();
  for (const gadget of state.gadgets.equipped) {
    for (const effect of gadget.effects) {
      const existing = totals.get(effect.stat) ?? { flat: 0, percent: 1.0 };
      existing.flat += effect.flatBonus;
      existing.percent *= effect.percentBonus;
      totals.set(effect.stat, existing);
    }
  }
  return totals;
}
