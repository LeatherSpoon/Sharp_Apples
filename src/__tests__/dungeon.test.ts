import { describe, it, expect } from "vitest";
import {
  Direction,
  OPPOSITE_DIRECTION,
  DIRECTION_OFFSET,
  PieceShape,
  PieceContent,
  MAP_PIECE_REGISTRY,
  findCompatiblePieces,
  generateDungeon,
  dungeonContentSummary,
  type DungeonConfig,
} from "../core/dungeon.js";

// Seeded RNG for deterministic tests
function seededRng(seed: number): () => number {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

describe("direction primitives", () => {
  it("opposite directions are correct", () => {
    expect(OPPOSITE_DIRECTION[Direction.North]).toBe(Direction.South);
    expect(OPPOSITE_DIRECTION[Direction.South]).toBe(Direction.North);
    expect(OPPOSITE_DIRECTION[Direction.East]).toBe(Direction.West);
    expect(OPPOSITE_DIRECTION[Direction.West]).toBe(Direction.East);
  });

  it("direction offsets are unit vectors", () => {
    for (const dir of Object.values(Direction)) {
      const offset = DIRECTION_OFFSET[dir];
      expect(Math.abs(offset.x) + Math.abs(offset.y)).toBe(1);
    }
  });
});

describe("MAP_PIECE_REGISTRY", () => {
  it("has all expected piece shapes", () => {
    const shapes = MAP_PIECE_REGISTRY.map((p) => p.shape);
    expect(shapes).toContain(PieceShape.Straight_NS);
    expect(shapes).toContain(PieceShape.Straight_EW);
    expect(shapes).toContain(PieceShape.I_Shape);
    expect(shapes).toContain(PieceShape.L_NE);
    expect(shapes).toContain(PieceShape.H_Shape);
    expect(shapes).toContain(PieceShape.C_East);
    expect(shapes).toContain(PieceShape.Cross);
    expect(shapes).toContain(PieceShape.DeadEnd_N);
  });

  it("every piece has at least one connector", () => {
    for (const piece of MAP_PIECE_REGISTRY) {
      expect(piece.connectors.length).toBeGreaterThanOrEqual(1);
    }
  });

  it("every piece has positive dimensions", () => {
    for (const piece of MAP_PIECE_REGISTRY) {
      expect(piece.width).toBeGreaterThan(0);
      expect(piece.height).toBeGreaterThan(0);
    }
  });

  it("dead ends have exactly 1 connector", () => {
    const deadEnds = MAP_PIECE_REGISTRY.filter((p) =>
      p.shape.startsWith("dead_end"),
    );
    for (const de of deadEnds) {
      expect(de.connectors).toHaveLength(1);
    }
  });

  it("cross piece has 4 connectors", () => {
    const cross = MAP_PIECE_REGISTRY.find((p) => p.shape === PieceShape.Cross);
    expect(cross).toBeDefined();
    expect(cross!.connectors).toHaveLength(4);
  });
});

describe("findCompatiblePieces", () => {
  it("finds pieces that can connect from the south going north", () => {
    const compatible = findCompatiblePieces(Direction.South, 0);
    // Should find pieces with a North connector
    expect(compatible.length).toBeGreaterThan(0);
    for (const p of compatible) {
      expect(p.connectors.some((c) => c.direction === Direction.North)).toBe(true);
    }
  });

  it("filters by tool tier", () => {
    const tier0 = findCompatiblePieces(Direction.North, 0);
    const tier5 = findCompatiblePieces(Direction.North, 5);
    // Tier 5 should have at least as many options as tier 0
    expect(tier5.length).toBeGreaterThanOrEqual(tier0.length);
  });
});

describe("generateDungeon", () => {
  it("generates a dungeon with the target number of pieces (or close)", () => {
    const config: DungeonConfig = {
      targetPieceCount: 10,
      maxToolTier: 0,
      minEntrances: 2,
      rng: seededRng(42),
    };
    const dungeon = generateDungeon(config);
    expect(dungeon.pieces.length).toBeGreaterThanOrEqual(3);
    expect(dungeon.pieces.length).toBeLessThanOrEqual(10);
  });

  it("produces at least the minimum number of entrances", () => {
    const config: DungeonConfig = {
      targetPieceCount: 12,
      maxToolTier: 0,
      minEntrances: 2,
      rng: seededRng(123),
    };
    const dungeon = generateDungeon(config);
    expect(dungeon.entrances.length).toBeGreaterThanOrEqual(2);
  });

  it("no two pieces share the same grid position", () => {
    const config: DungeonConfig = {
      targetPieceCount: 15,
      maxToolTier: 0,
      minEntrances: 1,
      rng: seededRng(999),
    };
    const dungeon = generateDungeon(config);
    const positions = new Set(dungeon.pieces.map((p) => `${p.gridPos.x},${p.gridPos.y}`));
    expect(positions.size).toBe(dungeon.pieces.length);
  });

  it("all pieces start unvisited", () => {
    const dungeon = generateDungeon({
      targetPieceCount: 8,
      maxToolTier: 0,
      minEntrances: 1,
      rng: seededRng(7),
    });
    for (const piece of dungeon.pieces) {
      expect(piece.visited).toBe(false);
    }
  });

  it("works with default config", () => {
    // Just ensure no errors with default config (uses Math.random)
    const dungeon = generateDungeon();
    expect(dungeon.pieces.length).toBeGreaterThan(0);
    expect(dungeon.entrances.length).toBeGreaterThan(0);
  });
});

describe("dungeonContentSummary", () => {
  it("counts content types correctly", () => {
    const dungeon = generateDungeon({
      targetPieceCount: 10,
      maxToolTier: 0,
      minEntrances: 1,
      rng: seededRng(42),
    });
    const summary = dungeonContentSummary(dungeon);
    let total = 0;
    for (const count of Object.values(summary)) {
      total += count;
    }
    expect(total).toBe(dungeon.pieces.length);
  });
});
