extends Node2D
## Spawns destructible trees, boulders, and the Master NPC in the overworld.
## Resources respawn after a cooldown so the player always has things to punch.
## Supports world travel — call apply_world() to switch visuals and resources.

signal world_changed(env_id: String)
signal mine_entrance_clicked
signal master_npc_clicked

# Exclusion zones — no resources spawn inside these (with 20px margin)
const EXCLUSION_ZONES: Array[Rect2] = [
	Rect2(-320, -370, 190, 190),   # Dojo: (-300,-350) to (-150,-200) + margin
	Rect2(130, -220, 240, 190),    # Pond: (150,-200) to (350,-50) + margin
	Rect2(-70, -520, 140, 1040),   # Path1 vertical: (-50,-500) to (50,500) + margin
	Rect2(-520, -50, 1040, 100),   # Path2 horizontal: (-500,-30) to (500,30) + margin
	Rect2(-420, -310, 80, 70),     # Mine entrance: (-380,-275) + margin
]

const RESPAWN_TIME: float = 10.0
const NUM_TREES: int = 12
const NUM_BOULDERS: int = 8
const SPAWN_RANGE: float = 450.0

var _respawn_queue: Array[Dictionary] = []
var _spawned_resources: Array[Node] = []
var _master_npc: Node = null
var _mine_entrance: Node = null
var _current_env_id: String = ""


func _ready() -> void:
	apply_world(GameState.environment.current_environment())


func _process(delta: float) -> void:
	var i := _respawn_queue.size() - 1
	while i >= 0:
		_respawn_queue[i]["timer"] -= delta
		if _respawn_queue[i]["timer"] <= 0:
			var entry: Dictionary = _respawn_queue[i]
			_create_resource(entry["type"], entry["pos"])
			_respawn_queue.remove_at(i)
		i -= 1


# ===========================================================================
#  WORLD SWITCHING
# ===========================================================================

func apply_world(env: Dictionary) -> void:
	var env_id: String = env["id"]
	_current_env_id = env_id

	# Update ground and path colors
	var ground: ColorRect = get_node_or_null("Ground")
	if ground:
		ground.color = env.get("ground_color", Color(0.18, 0.55, 0.22))

	var path1: ColorRect = get_node_or_null("Path1")
	var path2: ColorRect = get_node_or_null("Path2")
	var path_col: Color = env.get("path_color", Color(0.55, 0.4, 0.25))
	if path1:
		path1.color = path_col
	if path2:
		path2.color = path_col

	# Toggle landmark visibility
	var pond: ColorRect = get_node_or_null("Pond")
	if pond:
		pond.visible = env.get("has_pond", false)

	var dojo: ColorRect = get_node_or_null("Dojo")
	if dojo:
		dojo.visible = env.get("has_dojo", false)

	# Clear existing resources and respawn queue
	_clear_resources()
	_respawn_queue.clear()

	# Generate resources from seeded positions
	var positions := _generate_positions(env_id, NUM_TREES + NUM_BOULDERS)
	for idx in NUM_TREES:
		if idx < positions.size():
			_create_resource("tree", positions[idx])
	for idx in range(NUM_TREES, NUM_TREES + NUM_BOULDERS):
		if idx < positions.size():
			_create_resource("boulder", positions[idx])

	# Master NPC only in worlds with a dojo
	if _master_npc:
		_master_npc.queue_free()
		_master_npc = null
	if env.get("has_dojo", false):
		_spawn_master_npc()

	# Mine entrance only in Forest Dojo (leads to Deep Mine)
	if _mine_entrance:
		_mine_entrance.queue_free()
		_mine_entrance = null
	if env_id == "forest_dojo":
		_spawn_mine_entrance()

	# Move player to origin
	var player: Node2D = get_node_or_null("Player")
	if player:
		player.position = Vector2.ZERO

	world_changed.emit(env_id)


func _clear_resources() -> void:
	for node in _spawned_resources:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_resources.clear()


# Generate deterministic positions from a seed string
func _generate_positions(seed_str: String, count: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_str)
	var positions: Array[Vector2] = []
	var attempts := 0
	while positions.size() < count and attempts < count * 10:
		attempts += 1
		var x := rng.randf_range(-SPAWN_RANGE, SPAWN_RANGE)
		var y := rng.randf_range(-SPAWN_RANGE, SPAWN_RANGE)
		var pos := Vector2(x, y)
		if not _is_valid_spawn_pos(pos):
			continue
		# Check minimum distance from other positions
		var too_close := false
		for other in positions:
			if pos.distance_to(other) < 40.0:
				too_close = true
				break
		if too_close:
			continue
		positions.append(pos)
	return positions


func _is_valid_spawn_pos(pos: Vector2) -> bool:
	for zone in EXCLUSION_ZONES:
		if zone.has_point(pos):
			return false
	return true


# ===========================================================================
#  RESOURCE CREATION
# ===========================================================================

func _create_resource(type: String, pos: Vector2) -> void:
	var node := Area2D.new()
	node.position = pos
	node.input_pickable = true
	node.set_meta("resource_type", type)
	node.set_meta("resource_pos", pos)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()

	if type == "tree":
		rect.size = Vector2(20, 28)
		shape.shape = rect
		node.add_child(shape)

		var canopy := ColorRect.new()
		canopy.size = Vector2(24, 20)
		canopy.position = Vector2(-12, -24)
		canopy.color = Color(0.08, 0.45, 0.12)
		node.add_child(canopy)

		var trunk := ColorRect.new()
		trunk.size = Vector2(6, 14)
		trunk.position = Vector2(-3, -4)
		trunk.color = Color(0.4, 0.25, 0.1)
		node.add_child(trunk)
	else:
		rect.size = Vector2(26, 18)
		shape.shape = rect
		node.add_child(shape)

		var body := ColorRect.new()
		body.size = Vector2(26, 18)
		body.position = Vector2(-13, -9)
		body.color = Color(0.5, 0.47, 0.42)
		node.add_child(body)

		var highlight := ColorRect.new()
		highlight.size = Vector2(12, 6)
		highlight.position = Vector2(-6, -7)
		highlight.color = Color(0.6, 0.57, 0.52)
		node.add_child(highlight)

	node.input_event.connect(_on_resource_clicked.bind(node, type, pos))
	add_child(node)
	_spawned_resources.append(node)


func _on_resource_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, node: Area2D, type: String, pos: Vector2) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var player: Node2D = get_node_or_null("Player")
	if player == null:
		return
	if player.global_position.distance_to(node.global_position) > 64.0:
		return

	GameState.on_resource_destroyed(type)
	node.queue_free()
	_spawned_resources.erase(node)
	get_viewport().set_input_as_handled()

	_respawn_queue.append({
		"type": type,
		"pos": pos,
		"timer": RESPAWN_TIME,
	})

	_spawn_feedback(pos, "+STR" if type == "tree" else "+DEF")


func _spawn_feedback(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-16, -40)
	lbl.add_theme_font_size_override("font_size", 21)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", pos.y - 70, 1.0)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)


# ===========================================================================
#  MASTER NPC
# ===========================================================================

func _spawn_master_npc() -> void:
	var npc := CharacterBody2D.new()
	npc.position = Vector2(-225, -180)

	var npc_script: GDScript = load("res://scripts/overworld/npc_master.gd")
	npc.set_script(npc_script)

	var body := ColorRect.new()
	body.size = Vector2(14, 14)
	body.position = Vector2(-7, -7)
	body.color = Color(0.85, 0.65, 0.1)
	npc.add_child(body)

	var belt := ColorRect.new()
	belt.size = Vector2(14, 3)
	belt.position = Vector2(-7, 2)
	belt.color = Color(0.15, 0.15, 0.15)
	npc.add_child(belt)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	col.shape = rect
	npc.add_child(col)

	# Click detection area overlaid on NPC
	var click_area := Area2D.new()
	click_area.input_pickable = true
	var click_shape := CollisionShape2D.new()
	var click_rect := RectangleShape2D.new()
	click_rect.size = Vector2(28, 28)
	click_shape.shape = click_rect
	click_area.add_child(click_shape)
	click_area.input_event.connect(_on_master_clicked.bind(npc))
	npc.add_child(click_area)

	var name_label := Label.new()
	name_label.text = "Master"
	name_label.position = Vector2(-20, -24)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	npc.add_child(name_label)

	add_child(npc)
	_master_npc = npc


func _on_master_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, npc: Node2D) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var player: Node2D = get_node_or_null("Player")
	if player == null:
		return
	if player.global_position.distance_to(npc.global_position) > 80.0:
		return
	get_viewport().set_input_as_handled()
	master_npc_clicked.emit()


# ===========================================================================
#  MINE ENTRANCE
# ===========================================================================

func _spawn_mine_entrance() -> void:
	# Place west of dojo: dojo is at (-300,-350) to (-150,-200)
	# Mine entrance at (-380, -275) — just to the left of the dojo
	var entrance := Area2D.new()
	entrance.position = Vector2(-380, -275)
	entrance.input_pickable = true

	# Dark cave-like rectangle
	var bg := ColorRect.new()
	bg.size = Vector2(40, 36)
	bg.position = Vector2(-20, -18)
	bg.color = Color(0.12, 0.1, 0.1)
	entrance.add_child(bg)

	# Arch/entrance highlight
	var arch := ColorRect.new()
	arch.size = Vector2(30, 8)
	arch.position = Vector2(-15, -18)
	arch.color = Color(0.3, 0.22, 0.15)
	entrance.add_child(arch)

	# Inner darkness
	var inner := ColorRect.new()
	inner.size = Vector2(24, 24)
	inner.position = Vector2(-12, -10)
	inner.color = Color(0.05, 0.04, 0.04)
	entrance.add_child(inner)

	var label := Label.new()
	label.text = "Mine"
	label.position = Vector2(-16, -36)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	entrance.add_child(label)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 36)
	col.shape = rect
	entrance.add_child(col)

	entrance.input_event.connect(_on_mine_entrance_clicked.bind(entrance))
	add_child(entrance)
	_mine_entrance = entrance


func _on_mine_entrance_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, entrance: Node2D) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var player: Node2D = get_node_or_null("Player")
	if player == null:
		return
	if player.global_position.distance_to(entrance.global_position) > 80.0:
		return
	get_viewport().set_input_as_handled()
	mine_entrance_clicked.emit()
