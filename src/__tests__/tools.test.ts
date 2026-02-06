import { describe, it, expect } from "vitest";
import {
  ToolTier,
  GadgetSlotType,
  createEquipmentState,
  equipTool,
  unequipTool,
  getEquippedTool,
  getToolTier,
  toolEfficiencyMultiplier,
  equipGadget,
  unequipGadget,
  expandGadgetSlots,
  aggregateGadgetEffects,
  type ToolDefinition,
  type GadgetDefinition,
} from "../core/tools.js";
import { TrainingActivity } from "../core/variables.js";

const makePickaxe = (tier: ToolTier = ToolTier.Basic): ToolDefinition => ({
  id: `pickaxe_t${tier}`,
  name: `Tier ${tier} Pickaxe`,
  activity: TrainingActivity.Mining,
  tier,
  efficiencyMultiplier: 1.0 + tier * 0.25,
  description: "A mining pickaxe.",
});

const makeFishingRod = (): ToolDefinition => ({
  id: "fishing_rod_basic",
  name: "Basic Fishing Rod",
  activity: TrainingActivity.Fishing,
  tier: ToolTier.Basic,
  efficiencyMultiplier: 1.5,
  description: "A simple fishing rod.",
});

const makeCritGadget = (): GadgetDefinition => ({
  id: "lucky_charm",
  name: "Lucky Charm",
  slotType: GadgetSlotType.Offensive,
  effects: [
    { stat: "critChance", flatBonus: 0.05, percentBonus: 1.0 },
  ],
  description: "Increases crit chance.",
});

const makeSpeedGadget = (): GadgetDefinition => ({
  id: "swift_boots",
  name: "Swift Boots",
  slotType: GadgetSlotType.Utility,
  effects: [
    { stat: "speed", flatBonus: 10, percentBonus: 1.1 },
  ],
  description: "Increases movement speed.",
});

describe("tool operations", () => {
  it("starts with no tools equipped", () => {
    const state = createEquipmentState();
    expect(getEquippedTool(state, TrainingActivity.Mining)).toBeNull();
    expect(getToolTier(state, TrainingActivity.Mining)).toBe(ToolTier.None);
    expect(toolEfficiencyMultiplier(state, TrainingActivity.Mining)).toBe(1.0);
  });

  it("equips a tool to the correct activity slot", () => {
    const state = createEquipmentState();
    const pick = makePickaxe();
    const prev = equipTool(state, pick);

    expect(prev).toBeNull();
    expect(getEquippedTool(state, TrainingActivity.Mining)).toBe(pick);
    expect(getToolTier(state, TrainingActivity.Mining)).toBe(ToolTier.Basic);
    expect(toolEfficiencyMultiplier(state, TrainingActivity.Mining)).toBe(1.25);
  });

  it("replacing a tool returns the previous one", () => {
    const state = createEquipmentState();
    const basic = makePickaxe(ToolTier.Basic);
    const iron = makePickaxe(ToolTier.Iron);

    equipTool(state, basic);
    const prev = equipTool(state, iron);

    expect(prev).toBe(basic);
    expect(getEquippedTool(state, TrainingActivity.Mining)?.tier).toBe(ToolTier.Iron);
  });

  it("unequips a tool and returns it", () => {
    const state = createEquipmentState();
    const pick = makePickaxe();
    equipTool(state, pick);

    const removed = unequipTool(state, TrainingActivity.Mining);
    expect(removed).toBe(pick);
    expect(getEquippedTool(state, TrainingActivity.Mining)).toBeNull();
  });

  it("unequipping an empty slot returns null", () => {
    const state = createEquipmentState();
    expect(unequipTool(state, TrainingActivity.Mining)).toBeNull();
  });

  it("different activities have independent slots", () => {
    const state = createEquipmentState();
    const pick = makePickaxe();
    const rod = makeFishingRod();

    equipTool(state, pick);
    equipTool(state, rod);

    expect(getEquippedTool(state, TrainingActivity.Mining)).toBe(pick);
    expect(getEquippedTool(state, TrainingActivity.Fishing)).toBe(rod);
  });
});

describe("gadget operations", () => {
  it("starts with 1 gadget slot and none equipped", () => {
    const state = createEquipmentState();
    expect(state.gadgets.maxSlots).toBe(1);
    expect(state.gadgets.equipped).toHaveLength(0);
  });

  it("equips a gadget to an available slot", () => {
    const state = createEquipmentState();
    const success = equipGadget(state, makeCritGadget());
    expect(success).toBe(true);
    expect(state.gadgets.equipped).toHaveLength(1);
  });

  it("fails to equip when no slots available", () => {
    const state = createEquipmentState();
    equipGadget(state, makeCritGadget());
    const success = equipGadget(state, makeSpeedGadget());
    expect(success).toBe(false);
    expect(state.gadgets.equipped).toHaveLength(1);
  });

  it("unequips a gadget by index", () => {
    const state = createEquipmentState();
    const charm = makeCritGadget();
    equipGadget(state, charm);

    const removed = unequipGadget(state, 0);
    expect(removed).toBe(charm);
    expect(state.gadgets.equipped).toHaveLength(0);
  });

  it("returns null for invalid unequip index", () => {
    const state = createEquipmentState();
    expect(unequipGadget(state, -1)).toBeNull();
    expect(unequipGadget(state, 0)).toBeNull();
  });

  it("expandGadgetSlots increases max", () => {
    const state = createEquipmentState();
    expandGadgetSlots(state, 2);
    expect(state.gadgets.maxSlots).toBe(3);

    // Now we can equip 3
    equipGadget(state, makeCritGadget());
    equipGadget(state, makeSpeedGadget());
    equipGadget(state, makeCritGadget());
    expect(state.gadgets.equipped).toHaveLength(3);
  });

  it("expandGadgetSlots ignores non-positive values", () => {
    const state = createEquipmentState();
    expandGadgetSlots(state, 0);
    expandGadgetSlots(state, -1);
    expect(state.gadgets.maxSlots).toBe(1);
  });
});

describe("aggregateGadgetEffects", () => {
  it("returns empty map with no gadgets", () => {
    const state = createEquipmentState();
    const effects = aggregateGadgetEffects(state);
    expect(effects.size).toBe(0);
  });

  it("aggregates flat bonuses from single gadget", () => {
    const state = createEquipmentState();
    equipGadget(state, makeCritGadget());
    const effects = aggregateGadgetEffects(state);

    const crit = effects.get("critChance");
    expect(crit).toBeDefined();
    expect(crit!.flat).toBe(0.05);
    expect(crit!.percent).toBe(1.0);
  });

  it("aggregates effects from multiple gadgets", () => {
    const state = createEquipmentState();
    expandGadgetSlots(state, 1); // 2 slots total
    equipGadget(state, makeCritGadget());
    equipGadget(state, makeSpeedGadget());

    const effects = aggregateGadgetEffects(state);
    expect(effects.has("critChance")).toBe(true);
    expect(effects.has("speed")).toBe(true);
    expect(effects.get("speed")!.flat).toBe(10);
    expect(effects.get("speed")!.percent).toBeCloseTo(1.1);
  });
});
