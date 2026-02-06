import { describe, it, expect } from "vitest";
import {
  VariableKind,
  createControllingVariables,
  trainVariable,
  variableScaling,
  maxHP,
  energyPoolSize,
  energyRegenRate,
  BASE_HP,
  BASE_ENERGY_POOL,
  BASE_ENERGY_REGEN,
} from "../core/variables.js";

describe("ControllingVariables", () => {
  it("all start at 0", () => {
    const vars = createControllingVariables();
    expect(vars[VariableKind.Strength]).toBe(0);
    expect(vars[VariableKind.Dexterity]).toBe(0);
    expect(vars[VariableKind.Focus]).toBe(0);
    expect(vars[VariableKind.Endurance]).toBe(0);
  });

  it("trainVariable increases the chosen stat", () => {
    const vars = createControllingVariables();
    trainVariable(vars, VariableKind.Strength, 15);
    expect(vars[VariableKind.Strength]).toBe(15);
  });

  it("trainVariable ignores negative amounts", () => {
    const vars = createControllingVariables();
    trainVariable(vars, VariableKind.Strength, 10);
    trainVariable(vars, VariableKind.Strength, -5);
    expect(vars[VariableKind.Strength]).toBe(10);
  });
});

describe("variableScaling", () => {
  it("returns 0 when all variables are 0", () => {
    const vars = createControllingVariables();
    expect(variableScaling(vars, "unarmedDamage")).toBe(0);
  });

  it("scales unarmed damage primarily from Strength", () => {
    const vars = createControllingVariables();
    trainVariable(vars, VariableKind.Strength, 100);
    // Strength gives 0.02 per point to unarmedDamage
    expect(variableScaling(vars, "unarmedDamage")).toBeCloseTo(2.0);
  });

  it("energy scales primarily from Focus", () => {
    const vars = createControllingVariables();
    trainVariable(vars, VariableKind.Focus, 50);
    // Focus gives 0.01 per point to energyBonus
    // plus any cross-variable contributions
    expect(variableScaling(vars, "energyBonus")).toBeCloseTo(0.5);
  });

  it("all variables contribute to each theme", () => {
    const vars = createControllingVariables();
    trainVariable(vars, VariableKind.Strength, 10);
    trainVariable(vars, VariableKind.Dexterity, 10);
    trainVariable(vars, VariableKind.Focus, 10);
    trainVariable(vars, VariableKind.Endurance, 10);
    // All four contribute something to rangedBonus
    const scaling = variableScaling(vars, "rangedBonus");
    expect(scaling).toBeGreaterThan(0);
  });
});

describe("derived stats", () => {
  it("maxHP = BASE_HP + endurance", () => {
    expect(maxHP(0)).toBe(BASE_HP);
    expect(maxHP(50)).toBe(BASE_HP + 50);
  });

  it("energyPoolSize = 100 + focus * 5", () => {
    expect(energyPoolSize(0)).toBe(BASE_ENERGY_POOL);
    expect(energyPoolSize(20)).toBe(200);
  });

  it("energyRegenRate = 5 + focus * 0.5", () => {
    expect(energyRegenRate(0)).toBe(BASE_ENERGY_REGEN);
    expect(energyRegenRate(10)).toBe(10);
  });
});
