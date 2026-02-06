class_name Dungeon
## Dungeon / Cave procedural map generation.
##
## Pieces are stitched together by matching connectors on edges.
## The generator uses a frontier-based growth algorithm.
## 20 piece shapes: straights, I, L, T, H, C, cross, dead-ends.

enum Direction {
	NORTH,
	SOUTH,
	EAST,
	WEST,
}

const OPPOSITE: Dictionary = {
	Direction.NORTH: Direction.SOUTH,
	Direction.SOUTH: Direction.NORTH,
	Direction.EAST: Direction.WEST,
	Direction.WEST: Direction.EAST,
}

const DIR_OFFSET: Dictionary = {
	Direction.NORTH: Vector2i(0, -1),
	Direction.SOUTH: Vector2i(0, 1),
	Direction.EAST: Vector2i(1, 0),
	Direction.WEST: Vector2i(-1, 0),
}

enum PieceShape {
	STRAIGHT_NS, STRAIGHT_EW, I_SHAPE,
	L_NE, L_NW, L_SE, L_SW,
	T_NORTH, T_SOUTH, T_EAST, T_WEST,
	H_SHAPE, C_EAST, C_WEST, CROSS,
	DEAD_END_N, DEAD_END_S, DEAD_END_E, DEAD_END_W,
}

enum Content {
	EMPTY,
	MINING_NODE,
	OPPONENT,
	TREASURE,
	TOOL_GATE,
	HAZARD,
}


class MapPiece:
	var shape: int
	var width: int
	var height: int
	var connectors: Array[Dictionary] = []  # { direction, local_offset }
	var possible_content: Array[int] = []
	var required_tool_tier: int = 0


class PlacedPiece:
	var definition: MapPiece
	var grid_pos: Vector2i
	var content: int = Content.EMPTY
	var visited: bool = false
	var is_entrance: bool = false


## Full registry of the 20 piece templates.
static func build_registry() -> Array[MapPiece]:
	var reg: Array[MapPiece] = []

	# Helper to create pieces concisely
	var _add := func(shape: int, w: int, h: int, conns: Array, contents: Array, tier: int = 0) -> void:
		var p := MapPiece.new()
		p.shape = shape
		p.width = w
		p.height = h
		for c in conns:
			p.connectors.append({ "direction": c[0], "local_offset": c[1] })
		p.possible_content = contents
		p.required_tool_tier = tier
		reg.append(p)

	_add.call(PieceShape.STRAIGHT_NS, 3, 5, [[Direction.NORTH, 1], [Direction.SOUTH, 1]], [Content.EMPTY, Content.OPPONENT])
	_add.call(PieceShape.STRAIGHT_EW, 5, 3, [[Direction.EAST, 1], [Direction.WEST, 1]], [Content.EMPTY, Content.OPPONENT])
	_add.call(PieceShape.I_SHAPE, 5, 7, [[Direction.NORTH, 2], [Direction.SOUTH, 2]], [Content.MINING_NODE, Content.OPPONENT, Content.TREASURE])
	_add.call(PieceShape.L_NE, 5, 5, [[Direction.NORTH, 1], [Direction.EAST, 1]], [Content.EMPTY, Content.MINING_NODE])
	_add.call(PieceShape.L_NW, 5, 5, [[Direction.NORTH, 3], [Direction.WEST, 1]], [Content.EMPTY, Content.MINING_NODE])
	_add.call(PieceShape.L_SE, 5, 5, [[Direction.SOUTH, 1], [Direction.EAST, 3]], [Content.EMPTY, Content.OPPONENT])
	_add.call(PieceShape.L_SW, 5, 5, [[Direction.SOUTH, 3], [Direction.WEST, 3]], [Content.EMPTY, Content.OPPONENT])
	_add.call(PieceShape.T_NORTH, 5, 5, [[Direction.NORTH, 2], [Direction.EAST, 2], [Direction.WEST, 2]], [Content.OPPONENT, Content.MINING_NODE])
	_add.call(PieceShape.T_SOUTH, 5, 5, [[Direction.SOUTH, 2], [Direction.EAST, 2], [Direction.WEST, 2]], [Content.OPPONENT, Content.MINING_NODE])
	_add.call(PieceShape.T_EAST, 5, 5, [[Direction.NORTH, 2], [Direction.SOUTH, 2], [Direction.EAST, 2]], [Content.OPPONENT, Content.TREASURE])
	_add.call(PieceShape.T_WEST, 5, 5, [[Direction.NORTH, 2], [Direction.SOUTH, 2], [Direction.WEST, 2]], [Content.OPPONENT, Content.TREASURE])
	_add.call(PieceShape.H_SHAPE, 7, 7, [[Direction.NORTH, 1], [Direction.NORTH, 5], [Direction.SOUTH, 1], [Direction.SOUTH, 5]], [Content.MINING_NODE, Content.OPPONENT, Content.TREASURE])
	_add.call(PieceShape.C_EAST, 5, 7, [[Direction.NORTH, 4], [Direction.SOUTH, 4], [Direction.WEST, 3]], [Content.MINING_NODE, Content.HAZARD])
	_add.call(PieceShape.C_WEST, 5, 7, [[Direction.NORTH, 0], [Direction.SOUTH, 0], [Direction.EAST, 3]], [Content.MINING_NODE, Content.HAZARD])
	_add.call(PieceShape.CROSS, 5, 5, [[Direction.NORTH, 2], [Direction.SOUTH, 2], [Direction.EAST, 2], [Direction.WEST, 2]], [Content.OPPONENT, Content.TREASURE, Content.MINING_NODE])
	_add.call(PieceShape.DEAD_END_N, 3, 4, [[Direction.NORTH, 1]], [Content.TREASURE, Content.MINING_NODE])
	_add.call(PieceShape.DEAD_END_S, 3, 4, [[Direction.SOUTH, 1]], [Content.TREASURE, Content.MINING_NODE])
	_add.call(PieceShape.DEAD_END_E, 4, 3, [[Direction.EAST, 1]], [Content.TREASURE, Content.MINING_NODE])
	_add.call(PieceShape.DEAD_END_W, 4, 3, [[Direction.WEST, 1]], [Content.TREASURE, Content.MINING_NODE])

	return reg


## Generate a dungeon layout.
static func generate(
	target_piece_count: int = 12,
	max_tool_tier: int = 0,
	min_entrances: int = 2,
) -> Dictionary:
	var registry := build_registry()
	var occupied: Dictionary = {}  # "x,y" -> true
	var pieces: Array[PlacedPiece] = []

	# Frontier entries: { from_piece, connector, target_pos }
	var frontier: Array[Dictionary] = []

	# 1. Place starting piece (prefer 3+ connectors)
	var start_candidates: Array[MapPiece] = []
	for p in registry:
		if p.connectors.size() >= 3 and p.required_tool_tier <= max_tool_tier:
			start_candidates.append(p)
	var start_def: MapPiece
	if start_candidates.size() > 0:
		start_def = start_candidates[randi() % start_candidates.size()]
	else:
		start_def = registry[0]

	var start_pos := Vector2i.ZERO
	var start_piece := PlacedPiece.new()
	start_piece.definition = start_def
	start_piece.grid_pos = start_pos
	start_piece.content = _pick_content(start_def.possible_content)
	pieces.append(start_piece)
	occupied[_pos_key(start_pos)] = true

	for conn in start_def.connectors:
		var offset: Vector2i = DIR_OFFSET[conn["direction"]]
		frontier.append({
			"connector": conn,
			"target_pos": start_pos + offset,
		})

	# 2–4. Grow
	while pieces.size() < target_piece_count and frontier.size() > 0:
		var idx := randi() % frontier.size()
		var entry: Dictionary = frontier[idx]
		frontier.remove_at(idx)

		var target_key := _pos_key(entry["target_pos"])
		if occupied.has(target_key):
			continue

		var needed_dir: int = OPPOSITE[entry["connector"]["direction"]]
		var compatible: Array[MapPiece] = []
		for p in registry:
			if p.required_tool_tier > max_tool_tier:
				continue
			for c in p.connectors:
				if c["direction"] == needed_dir:
					compatible.append(p)
					break

		if compatible.size() == 0:
			continue

		var progress := float(pieces.size()) / float(target_piece_count)
		var candidates: Array[MapPiece] = []
		if progress < 0.7:
			for p in compatible:
				if p.connectors.size() >= 2:
					candidates.append(p)
		if candidates.size() == 0:
			candidates = compatible

		var chosen: MapPiece = candidates[randi() % candidates.size()]
		var new_piece := PlacedPiece.new()
		new_piece.definition = chosen
		new_piece.grid_pos = entry["target_pos"]
		new_piece.content = _pick_content(chosen.possible_content)
		pieces.append(new_piece)
		occupied[target_key] = true

		for conn in chosen.connectors:
			if conn["direction"] == needed_dir:
				continue
			var offset: Vector2i = DIR_OFFSET[conn["direction"]]
			frontier.append({
				"connector": conn,
				"target_pos": entry["target_pos"] + offset,
			})

	# 5–6. Mark entrances
	var entrances: Array[PlacedPiece] = []
	for piece in pieces:
		for conn in piece.definition.connectors:
			var offset: Vector2i = DIR_OFFSET[conn["direction"]]
			var neighbor_key := _pos_key(piece.grid_pos + offset)
			if not occupied.has(neighbor_key):
				if not piece.is_entrance:
					piece.is_entrance = true
					entrances.append(piece)
				break

	if entrances.size() < min_entrances:
		for piece in pieces:
			if piece.is_entrance:
				continue
			if entrances.size() >= min_entrances:
				break
			for conn in piece.definition.connectors:
				var offset: Vector2i = DIR_OFFSET[conn["direction"]]
				if not occupied.has(_pos_key(piece.grid_pos + offset)):
					piece.is_entrance = true
					entrances.append(piece)
					break

	return {
		"pieces": pieces,
		"entrances": entrances,
		"occupied": occupied,
	}


static func _pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func _pick_content(possible: Array) -> int:
	if possible.size() == 0:
		return Content.EMPTY
	return possible[randi() % possible.size()]


static func content_summary(dungeon: Dictionary) -> Dictionary:
	var counts := {
		Content.EMPTY: 0,
		Content.MINING_NODE: 0,
		Content.OPPONENT: 0,
		Content.TREASURE: 0,
		Content.TOOL_GATE: 0,
		Content.HAZARD: 0,
	}
	for piece: PlacedPiece in dungeon["pieces"]:
		counts[piece.content] = counts.get(piece.content, 0) + 1
	return counts
