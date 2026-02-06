/**
 * Dungeon / Cave Map Piece Generation
 *
 * The mountain cave is a procedurally assembled map. Each attempt uses
 * a random selection and arrangement of predefined map pieces.
 *
 * Map pieces come in named shapes (I, H, L, C, T, straight, etc.).
 * Each piece has 1+ connectors (entry/exit points) on its edges.
 * The generator stitches pieces together by matching connectors,
 * producing a non-linear explorable dungeon.
 *
 * Minimum: 1 entrance/exit. Preferred: 2+ entrance/exits.
 *
 * The cave supports mining, combat, and exploration. Tool/gadget
 * requirements will gate access to certain piece types later.
 */

// ---------------------------------------------------------------------------
// Grid and direction primitives
// ---------------------------------------------------------------------------

export enum Direction {
  North = "north",
  South = "south",
  East = "east",
  West = "west",
}

export const OPPOSITE_DIRECTION: Record<Direction, Direction> = {
  [Direction.North]: Direction.South,
  [Direction.South]: Direction.North,
  [Direction.East]: Direction.West,
  [Direction.West]: Direction.East,
};

export interface GridPosition {
  x: number;
  y: number;
}

/** Offset to apply when moving in a direction on the piece grid. */
export const DIRECTION_OFFSET: Record<Direction, GridPosition> = {
  [Direction.North]: { x: 0, y: -1 },
  [Direction.South]: { x: 0, y: 1 },
  [Direction.East]: { x: 1, y: 0 },
  [Direction.West]: { x: -1, y: 0 },
};

// ---------------------------------------------------------------------------
// Map piece definitions
// ---------------------------------------------------------------------------

export enum PieceShape {
  /** Long vertical corridor — N/S connectors. */
  Straight_NS = "straight_ns",
  /** Long horizontal corridor — E/W connectors. */
  Straight_EW = "straight_ew",
  /** Capital I — N/S connectors, wider middle section. */
  I_Shape = "i_shape",
  /** L bend — two connectors at a 90° angle. */
  L_NE = "l_ne",
  L_NW = "l_nw",
  L_SE = "l_se",
  L_SW = "l_sw",
  /** T junction — three connectors. */
  T_North = "t_north",
  T_South = "t_south",
  T_East = "t_east",
  T_West = "t_west",
  /** H shape — N/S connectors on both sides, connected by a bridge. */
  H_Shape = "h_shape",
  /** C shape — opens East with N/S/W connectors. */
  C_East = "c_east",
  /** C shape — opens West with N/S/E connectors. */
  C_West = "c_west",
  /** Cross / + — all four connectors. */
  Cross = "cross",
  /** Dead end — single connector. Good for treasure rooms. */
  DeadEnd_N = "dead_end_n",
  DeadEnd_S = "dead_end_s",
  DeadEnd_E = "dead_end_e",
  DeadEnd_W = "dead_end_w",
}

export interface Connector {
  direction: Direction;
  /** Local position on the piece edge (for alignment). */
  localOffset: number;
}

/** Content that can appear inside a map piece. */
export enum PieceContent {
  Empty = "empty",
  MiningNode = "mining_node",
  Opponent = "opponent",
  Treasure = "treasure",
  /** Placeholder for future tool/gadget gating. */
  ToolGate = "tool_gate",
  /** Environmental hazard (damage, slow, etc.). */
  Hazard = "hazard",
}

export interface MapPieceDefinition {
  shape: PieceShape;
  /** Width in tiles. */
  width: number;
  /** Height in tiles. */
  height: number;
  /** Connectors (entry/exit points) on this piece. */
  connectors: Connector[];
  /** What content categories this piece can contain. */
  possibleContent: PieceContent[];
  /** Minimum tool tier required to enter (0 = no tool needed). */
  requiredToolTier: number;
}

/**
 * Registry of all map piece templates.
 * Each entry defines the shape, dimensions, connectors, and possible content.
 */
export const MAP_PIECE_REGISTRY: MapPieceDefinition[] = [
  // Straight corridors
  {
    shape: PieceShape.Straight_NS,
    width: 3,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 1 },
      { direction: Direction.South, localOffset: 1 },
    ],
    possibleContent: [PieceContent.Empty, PieceContent.Opponent],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.Straight_EW,
    width: 5,
    height: 3,
    connectors: [
      { direction: Direction.East, localOffset: 1 },
      { direction: Direction.West, localOffset: 1 },
    ],
    possibleContent: [PieceContent.Empty, PieceContent.Opponent],
    requiredToolTier: 0,
  },

  // I shape — wider room in middle
  {
    shape: PieceShape.I_Shape,
    width: 5,
    height: 7,
    connectors: [
      { direction: Direction.North, localOffset: 2 },
      { direction: Direction.South, localOffset: 2 },
    ],
    possibleContent: [
      PieceContent.MiningNode,
      PieceContent.Opponent,
      PieceContent.Treasure,
    ],
    requiredToolTier: 0,
  },

  // L bends
  {
    shape: PieceShape.L_NE,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 1 },
      { direction: Direction.East, localOffset: 1 },
    ],
    possibleContent: [PieceContent.Empty, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.L_NW,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 3 },
      { direction: Direction.West, localOffset: 1 },
    ],
    possibleContent: [PieceContent.Empty, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.L_SE,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.South, localOffset: 1 },
      { direction: Direction.East, localOffset: 3 },
    ],
    possibleContent: [PieceContent.Empty, PieceContent.Opponent],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.L_SW,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.South, localOffset: 3 },
      { direction: Direction.West, localOffset: 3 },
    ],
    possibleContent: [PieceContent.Empty, PieceContent.Opponent],
    requiredToolTier: 0,
  },

  // T junctions — three connectors
  {
    shape: PieceShape.T_North,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 2 },
      { direction: Direction.East, localOffset: 2 },
      { direction: Direction.West, localOffset: 2 },
    ],
    possibleContent: [PieceContent.Opponent, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.T_South,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.South, localOffset: 2 },
      { direction: Direction.East, localOffset: 2 },
      { direction: Direction.West, localOffset: 2 },
    ],
    possibleContent: [PieceContent.Opponent, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.T_East,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 2 },
      { direction: Direction.South, localOffset: 2 },
      { direction: Direction.East, localOffset: 2 },
    ],
    possibleContent: [PieceContent.Opponent, PieceContent.Treasure],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.T_West,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 2 },
      { direction: Direction.South, localOffset: 2 },
      { direction: Direction.West, localOffset: 2 },
    ],
    possibleContent: [PieceContent.Opponent, PieceContent.Treasure],
    requiredToolTier: 0,
  },

  // H shape
  {
    shape: PieceShape.H_Shape,
    width: 7,
    height: 7,
    connectors: [
      { direction: Direction.North, localOffset: 1 },
      { direction: Direction.North, localOffset: 5 },
      { direction: Direction.South, localOffset: 1 },
      { direction: Direction.South, localOffset: 5 },
    ],
    possibleContent: [
      PieceContent.MiningNode,
      PieceContent.Opponent,
      PieceContent.Treasure,
    ],
    requiredToolTier: 0,
  },

  // C shapes
  {
    shape: PieceShape.C_East,
    width: 5,
    height: 7,
    connectors: [
      { direction: Direction.North, localOffset: 4 },
      { direction: Direction.South, localOffset: 4 },
      { direction: Direction.West, localOffset: 3 },
    ],
    possibleContent: [PieceContent.MiningNode, PieceContent.Hazard],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.C_West,
    width: 5,
    height: 7,
    connectors: [
      { direction: Direction.North, localOffset: 0 },
      { direction: Direction.South, localOffset: 0 },
      { direction: Direction.East, localOffset: 3 },
    ],
    possibleContent: [PieceContent.MiningNode, PieceContent.Hazard],
    requiredToolTier: 0,
  },

  // Cross / + — all four connectors
  {
    shape: PieceShape.Cross,
    width: 5,
    height: 5,
    connectors: [
      { direction: Direction.North, localOffset: 2 },
      { direction: Direction.South, localOffset: 2 },
      { direction: Direction.East, localOffset: 2 },
      { direction: Direction.West, localOffset: 2 },
    ],
    possibleContent: [
      PieceContent.Opponent,
      PieceContent.Treasure,
      PieceContent.MiningNode,
    ],
    requiredToolTier: 0,
  },

  // Dead ends — treasure rooms, mining pockets
  {
    shape: PieceShape.DeadEnd_N,
    width: 3,
    height: 4,
    connectors: [{ direction: Direction.North, localOffset: 1 }],
    possibleContent: [PieceContent.Treasure, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.DeadEnd_S,
    width: 3,
    height: 4,
    connectors: [{ direction: Direction.South, localOffset: 1 }],
    possibleContent: [PieceContent.Treasure, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.DeadEnd_E,
    width: 4,
    height: 3,
    connectors: [{ direction: Direction.East, localOffset: 1 }],
    possibleContent: [PieceContent.Treasure, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
  {
    shape: PieceShape.DeadEnd_W,
    width: 4,
    height: 3,
    connectors: [{ direction: Direction.West, localOffset: 1 }],
    possibleContent: [PieceContent.Treasure, PieceContent.MiningNode],
    requiredToolTier: 0,
  },
];

// ---------------------------------------------------------------------------
// Placed piece (instance in a generated dungeon)
// ---------------------------------------------------------------------------

export interface PlacedPiece {
  definition: MapPieceDefinition;
  /** Position on the dungeon grid (in piece-grid coordinates). */
  gridPos: GridPosition;
  /** Content spawned in this instance. */
  content: PieceContent;
  /** Whether this piece has been visited by the player. */
  visited: boolean;
  /** Whether this piece is an entrance/exit. */
  isEntrance: boolean;
}

// ---------------------------------------------------------------------------
// Dungeon generation
// ---------------------------------------------------------------------------

export interface DungeonConfig {
  /** Target number of pieces (actual may be slightly less if placement fails). */
  targetPieceCount: number;
  /** Max tool tier available (filters out gated pieces). */
  maxToolTier: number;
  /** Minimum number of entrance/exit points. */
  minEntrances: number;
  /** Random seed function (for deterministic generation). */
  rng?: () => number;
}

export const DEFAULT_DUNGEON_CONFIG: DungeonConfig = {
  targetPieceCount: 12,
  maxToolTier: 0,
  minEntrances: 2,
};

export interface GeneratedDungeon {
  pieces: PlacedPiece[];
  entrances: PlacedPiece[];
  /** The grid positions that are occupied. */
  occupiedPositions: Set<string>;
}

function posKey(pos: GridPosition): string {
  return `${pos.x},${pos.y}`;
}

/**
 * Find pieces in the registry that can connect in a given direction
 * and meet the tool tier requirement.
 */
export function findCompatiblePieces(
  direction: Direction,
  maxToolTier: number,
): MapPieceDefinition[] {
  const needed = OPPOSITE_DIRECTION[direction];
  return MAP_PIECE_REGISTRY.filter(
    (p) =>
      p.requiredToolTier <= maxToolTier &&
      p.connectors.some((c) => c.direction === needed),
  );
}

/**
 * Pick content for a placed piece based on its definition's possible content.
 */
function pickContent(
  possibleContent: PieceContent[],
  rng: () => number,
): PieceContent {
  if (possibleContent.length === 0) return PieceContent.Empty;
  return possibleContent[Math.floor(rng() * possibleContent.length)];
}

/**
 * Generate a dungeon layout by stitching map pieces together.
 *
 * Algorithm:
 * 1. Place a starting piece (cross or T for max connectivity).
 * 2. Maintain a frontier of unmatched connectors.
 * 3. For each frontier connector, find a compatible piece and place it.
 * 4. Repeat until target piece count is reached or frontier is exhausted.
 * 5. Cap remaining open connectors with dead ends.
 * 6. Ensure minimum entrance/exit count.
 */
export function generateDungeon(
  config: DungeonConfig = DEFAULT_DUNGEON_CONFIG,
): GeneratedDungeon {
  const rng = config.rng ?? Math.random;
  const occupied = new Set<string>();
  const pieces: PlacedPiece[] = [];

  // Frontier: open connectors that need matching
  interface FrontierEntry {
    fromPiece: PlacedPiece;
    connector: Connector;
    targetGridPos: GridPosition;
  }
  const frontier: FrontierEntry[] = [];

  // --- 1. Place starting piece ---
  const startCandidates = MAP_PIECE_REGISTRY.filter(
    (p) => p.connectors.length >= 3 && p.requiredToolTier <= config.maxToolTier,
  );
  const startDef =
    startCandidates[Math.floor(rng() * startCandidates.length)] ??
    MAP_PIECE_REGISTRY[0];
  const startPos: GridPosition = { x: 0, y: 0 };

  const startPiece: PlacedPiece = {
    definition: startDef,
    gridPos: startPos,
    content: pickContent(startDef.possibleContent, rng),
    visited: false,
    isEntrance: false,
  };
  pieces.push(startPiece);
  occupied.add(posKey(startPos));

  // Add starting piece's connectors to frontier
  for (const conn of startDef.connectors) {
    const offset = DIRECTION_OFFSET[conn.direction];
    frontier.push({
      fromPiece: startPiece,
      connector: conn,
      targetGridPos: { x: startPos.x + offset.x, y: startPos.y + offset.y },
    });
  }

  // --- 2–4. Grow the dungeon ---
  while (pieces.length < config.targetPieceCount && frontier.length > 0) {
    // Pick a random frontier entry
    const idx = Math.floor(rng() * frontier.length);
    const entry = frontier[idx];
    frontier.splice(idx, 1);

    // Skip if target position is already occupied
    if (occupied.has(posKey(entry.targetGridPos))) continue;

    // Find compatible pieces
    const compatible = findCompatiblePieces(
      entry.connector.direction,
      config.maxToolTier,
    );
    if (compatible.length === 0) continue;

    // Prefer multi-connector pieces early, dead ends later
    const progress = pieces.length / config.targetPieceCount;
    const filtered =
      progress < 0.7
        ? compatible.filter((p) => p.connectors.length >= 2)
        : compatible;
    const candidates = filtered.length > 0 ? filtered : compatible;

    const chosenDef = candidates[Math.floor(rng() * candidates.length)];
    const newPiece: PlacedPiece = {
      definition: chosenDef,
      gridPos: entry.targetGridPos,
      content: pickContent(chosenDef.possibleContent, rng),
      visited: false,
      isEntrance: false,
    };
    pieces.push(newPiece);
    occupied.add(posKey(entry.targetGridPos));

    // Add new piece's unmatched connectors to frontier
    for (const conn of chosenDef.connectors) {
      // Skip the connector that matches back to the piece we came from
      if (conn.direction === OPPOSITE_DIRECTION[entry.connector.direction]) {
        continue;
      }
      const offset = DIRECTION_OFFSET[conn.direction];
      const newTarget: GridPosition = {
        x: entry.targetGridPos.x + offset.x,
        y: entry.targetGridPos.y + offset.y,
      };
      frontier.push({
        fromPiece: newPiece,
        connector: conn,
        targetGridPos: newTarget,
      });
    }
  }

  // --- 5–6. Mark entrances ---
  // Find pieces with open (unmatched) connectors — these become entrances
  const entrances: PlacedPiece[] = [];
  for (const piece of pieces) {
    for (const conn of piece.definition.connectors) {
      const offset = DIRECTION_OFFSET[conn.direction];
      const neighborPos: GridPosition = {
        x: piece.gridPos.x + offset.x,
        y: piece.gridPos.y + offset.y,
      };
      if (!occupied.has(posKey(neighborPos))) {
        if (!piece.isEntrance) {
          piece.isEntrance = true;
          entrances.push(piece);
        }
      }
    }
  }

  // If not enough entrances, mark edge pieces
  if (entrances.length < config.minEntrances) {
    for (const piece of pieces) {
      if (piece.isEntrance) continue;
      if (entrances.length >= config.minEntrances) break;
      // Check if on the edge of the dungeon grid
      const hasOpenSide = piece.definition.connectors.some((conn) => {
        const offset = DIRECTION_OFFSET[conn.direction];
        const neighborPos = {
          x: piece.gridPos.x + offset.x,
          y: piece.gridPos.y + offset.y,
        };
        return !occupied.has(posKey(neighborPos));
      });
      if (hasOpenSide) {
        piece.isEntrance = true;
        entrances.push(piece);
      }
    }
  }

  return { pieces, entrances, occupiedPositions: occupied };
}

/**
 * Count pieces by content type in a generated dungeon.
 */
export function dungeonContentSummary(
  dungeon: GeneratedDungeon,
): Record<PieceContent, number> {
  const counts = {
    [PieceContent.Empty]: 0,
    [PieceContent.MiningNode]: 0,
    [PieceContent.Opponent]: 0,
    [PieceContent.Treasure]: 0,
    [PieceContent.ToolGate]: 0,
    [PieceContent.Hazard]: 0,
  };
  for (const piece of dungeon.pieces) {
    counts[piece.content]++;
  }
  return counts;
}
