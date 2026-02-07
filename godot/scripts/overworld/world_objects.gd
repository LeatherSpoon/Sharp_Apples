extends Node2D
## Spawns destructible trees, boulders, and the Master NPC in the overworld.
## Resources respawn after a cooldown so the player always has things to punch.

const TREE_POSITIONS: Array[Vector2] = [
	Vector2(-400, -100), Vector2(-350, 50), Vector2(-180, -300),
	Vector2(100, 150), Vector2(280, -120), Vector2(420, 200),
	Vector2(-120, 320), Vector2(380, 330), Vector2(-450, 250),
	Vector2(150, -400), Vector2(-80, -150), Vector2(450, -50),
]

const BOULDER_POSITIONS: Array[Vector2] = [
	Vector2(-300, 200), Vector2(200, 280), Vector2(-430, -200),
	Vector2(400, -320), Vector2(0, 420), Vector2(-200, 100),
	Vector2(320, 50), Vector2(-380, 350),
]

const RESPAWN_TIME: float = 10.0  # seconds until resources reappear
var _respawn_queue: Array[Dictionary] = []


func _ready() -> void:
	_spawn_all_trees()
	_spawn_all_boulders()
	_spawn_master_npc()


func _process(delta: float) -> void:
	var i := _respawn_queue.size() - 1
	while i >= 0:
		_respawn_queue[i]["timer"] -= delta
		if _respawn_queue[i]["timer"] <= 0:
			var entry: Dictionary = _respawn_queue[i]
			_create_resource(entry["type"], entry["pos"])
			_respawn_queue.remove_at(i)
		i -= 1


# ---- Tree spawning ----

func _spawn_all_trees() -> void:
	for pos in TREE_POSITIONS:
		_create_resource("tree", pos)


func _spawn_all_boulders() -> void:
	for pos in BOULDER_POSITIONS:
		_create_resource("boulder", pos)


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

		# Canopy
		var canopy := ColorRect.new()
		canopy.size = Vector2(24, 20)
		canopy.position = Vector2(-12, -24)
		canopy.color = Color(0.08, 0.45, 0.12)
		node.add_child(canopy)

		# Trunk
		var trunk := ColorRect.new()
		trunk.size = Vector2(6, 14)
		trunk.position = Vector2(-3, -4)
		trunk.color = Color(0.4, 0.25, 0.1)
		node.add_child(trunk)
	else:
		rect.size = Vector2(26, 18)
		shape.shape = rect
		node.add_child(shape)

		# Boulder body
		var body := ColorRect.new()
		body.size = Vector2(26, 18)
		body.position = Vector2(-13, -9)
		body.color = Color(0.5, 0.47, 0.42)
		node.add_child(body)

		# Highlight
		var highlight := ColorRect.new()
		highlight.size = Vector2(12, 6)
		highlight.position = Vector2(-6, -7)
		highlight.color = Color(0.6, 0.57, 0.52)
		node.add_child(highlight)

	node.input_event.connect(_on_resource_clicked.bind(node, type, pos))
	add_child(node)


func _on_resource_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, node: Area2D, type: String, pos: Vector2) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Check player is close enough to punch
	var player: Node2D = get_node_or_null("Player")
	if player == null:
		return
	if player.global_position.distance_to(node.global_position) > 64.0:
		return

	# Destroy it
	GameState.on_resource_destroyed(type)
	node.queue_free()
	get_viewport().set_input_as_handled()

	# Queue respawn
	_respawn_queue.append({
		"type": type,
		"pos": pos,
		"timer": RESPAWN_TIME,
	})

	# Floating feedback text
	_spawn_feedback(pos, "+STR" if type == "tree" else "+DEF")


func _spawn_feedback(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(-16, -40)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", pos.y - 70, 1.0)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)


# ---- Master NPC ----

func _spawn_master_npc() -> void:
	# Dojo is at (-300, -350) to (-150, -200). Front is around y = -185
	var npc := CharacterBody2D.new()
	npc.position = Vector2(-225, -180)

	var npc_script: GDScript = load("res://scripts/overworld/npc_master.gd")
	npc.set_script(npc_script)

	# Body (golden/orange)
	var body := ColorRect.new()
	body.size = Vector2(14, 14)
	body.position = Vector2(-7, -7)
	body.color = Color(0.85, 0.65, 0.1)
	npc.add_child(body)

	# Belt (darker)
	var belt := ColorRect.new()
	belt.size = Vector2(14, 3)
	belt.position = Vector2(-7, 2)
	belt.color = Color(0.15, 0.15, 0.15)
	npc.add_child(belt)

	# Collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	col.shape = rect
	npc.add_child(col)

	# Name label
	var name_label := Label.new()
	name_label.text = "Master"
	name_label.position = Vector2(-20, -24)
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	npc.add_child(name_label)

	add_child(npc)
