extends Node2D

# Playable Exploration Mode skeleton:
# - fixed hidden nests are discovered by mining their cells;
# - nest difficulty scales by depth and nests periodically release enemies;
# - three buried artifacts improve the hero;
# - uncovering the bottom gate after collecting every artifact summons a boss.

const ENEMY_SCENE := preload("res://enemy.tscn")
const BASE_TARGET_CELL := Vector2i(0, -1)
const REQUIRED_ARTIFACTS := 3
const MAX_ACTIVE_ENEMIES := 12
const NEST_INTERACT_DISTANCE := 92.0
const ARTIFACT_PICKUP_DISTANCE := 62.0
const BOSS_GATE_CELL := Vector2i(0, 28)

const NEST_DEFINITIONS := [
	{"cell": Vector2i(-9, 6), "zone": 1, "name": "Shallow Burrow", "interval": 15.0},
	{"cell": Vector2i(10, 10), "zone": 1, "name": "Crawler Den", "interval": 14.0},
	{"cell": Vector2i(-12, 17), "zone": 2, "name": "Chittering Colony", "interval": 12.0},
	{"cell": Vector2i(12, 21), "zone": 3, "name": "Deep Brood", "interval": 10.0},
	{"cell": Vector2i(-6, 25), "zone": 3, "name": "Abyssal Hive", "interval": 8.5},
]

const ARTIFACT_DEFINITIONS := [
	{"cell": Vector2i(14, 13), "name": "Echo Shard"},
	{"cell": Vector2i(-15, 20), "name": "Heart of Stone"},
	{"cell": Vector2i(5, 27), "name": "Depth Compass"},
]

var world: Node2D
var block_layer: TileMapLayer
var player: CharacterBody2D
var hud: Node
var topology_seen := -1
var nests: Array[Dictionary] = []
var artifacts: Array[Dictionary] = []
var artifacts_collected := 0
var nests_destroyed := 0
var boss_spawned := false
var boss_node: Node2D
var boss_seal: Node2D
var exploration_complete := false
var nest_hit_cooldown := 0.0
var ui_refresh_timer := 0.0
var objective_layer: CanvasLayer
var status_label: Label
var hint_label: Label
var nearby_hint := ""

func _ready() -> void:
	call_deferred("_activate")

func _activate() -> void:
	world = get_parent() as Node2D
	if world == null or not is_instance_valid(world):
		queue_free()
		return
	if bool(world.get("is_vs_mode")) or not GameMode.is_exploration():
		queue_free()
		return

	block_layer = world.get_node_or_null("BlockLayer") as TileMapLayer
	player = world.get_node_or_null("Player") as CharacterBody2D
	hud = world.get_node_or_null("HUD")
	if block_layer == null or player == null:
		push_error("Exploration Mode requires BlockLayer and Player.")
		queue_free()
		return

	# Exploration pressure is produced by discovered nests, not scheduled waves.
	world.set_process(false)
	world.set_meta("exploration_mode", true)
	world.set_meta("wave_spawning", false)
	world.current_breach_valid = false
	if world.breach_marker != null and is_instance_valid(world.breach_marker):
		world.breach_marker.visible = false

	for definition_value in NEST_DEFINITIONS:
		var definition: Dictionary = definition_value
		nests.append({
			"cell": definition["cell"],
			"zone": int(definition["zone"]),
			"name": String(definition["name"]),
			"interval": float(definition["interval"]),
			"cooldown": 3.0,
			"discovered": false,
			"destroyed": false,
			"hinted": false,
			"health": 2 + int(definition["zone"]),
			"max_health": 2 + int(definition["zone"]),
			"spawned": 0,
			"node": null,
			"label": null,
		})

	for definition_value in ARTIFACT_DEFINITIONS:
		var definition: Dictionary = definition_value
		artifacts.append({
			"cell": definition["cell"],
			"name": String(definition["name"]),
			"revealed": false,
			"collected": false,
			"hinted": false,
			"node": null,
		})

	_create_objective_ui()
	_evaluate_discoveries()
	_update_objective_ui()
	if hud and hud.has_method("show_notice"):
		hud.show_notice("EXPLORATION: dig deeper, uncover artifacts, and survive the nests below.", 5.5)

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or not GameMode.is_exploration():
		return

	# Keep the old ten-wave match director dormant until the exploration boss dies.
	if not exploration_complete:
		var match_flow := get_node_or_null("/root/MatchFlow")
		if match_flow:
			match_flow.intro_shown = true
			match_flow.result_shown = true

	nest_hit_cooldown = maxf(nest_hit_cooldown - delta, 0.0)
	var revision := int(world.get("topology_revision"))
	if revision != topology_seen:
		topology_seen = revision
		_evaluate_discoveries()

	nearby_hint = ""
	_update_proximity_hints()
	_update_nests(delta)
	_update_artifact_pickups()
	_update_boss_gate()

	ui_refresh_timer -= delta
	if ui_refresh_timer <= 0.0:
		ui_refresh_timer = 0.18
		_update_objective_ui()

func _evaluate_discoveries() -> void:
	for i in range(nests.size()):
		var state: Dictionary = nests[i]
		if not bool(state["discovered"]) and not _is_solid(state["cell"]):
			_discover_nest(i)

	for i in range(artifacts.size()):
		var state: Dictionary = artifacts[i]
		if not bool(state["revealed"]) and not _is_solid(state["cell"]):
			_reveal_artifact(i)

func _discover_nest(index: int) -> void:
	var state: Dictionary = nests[index]
	state["discovered"] = true
	state["cooldown"] = 2.8
	var visual := _create_nest_visual(state)
	state["node"] = visual
	state["label"] = visual.get_node_or_null("Status")
	nests[index] = state
	_update_nest_label(index)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("NEST DISCOVERED: %s. Press E nearby to destroy it before it keeps spawning enemies." % state["name"], 5.0)

func _reveal_artifact(index: int) -> void:
	var state: Dictionary = artifacts[index]
	state["revealed"] = true
	state["node"] = _create_artifact_visual(state)
	artifacts[index] = state
	if hud and hud.has_method("show_notice"):
		hud.show_notice("An ancient artifact has been uncovered. Touch it to claim its power.", 3.8)

func _update_proximity_hints() -> void:
	var player_cell := _player_cell()
	for i in range(nests.size()):
		var state: Dictionary = nests[i]
		if bool(state["discovered"]) or bool(state["destroyed"]):
			continue
		var distance := _grid_distance(player_cell, state["cell"])
		if distance <= 4:
			nearby_hint = "The dirt is trembling. A nest is close."
			if not bool(state["hinted"]) and hud and hud.has_method("show_notice"):
				state["hinted"] = true
				nests[i] = state
				hud.show_notice("You hear creatures moving behind the nearby rock.", 3.2)
			return

	for i in range(artifacts.size()):
		var state: Dictionary = artifacts[i]
		if bool(state["revealed"]) or bool(state["collected"]):
			continue
		var distance := _grid_distance(player_cell, state["cell"])
		if distance <= 3:
			nearby_hint = "A strange resonance hums through the rock."
			if not bool(state["hinted"]) and hud and hud.has_method("show_notice"):
				state["hinted"] = true
				artifacts[i] = state
				hud.show_notice("Something powerful is buried very close by.", 3.2)
			return

func _update_nests(delta: float) -> void:
	var closest_attackable := -1
	var closest_distance := INF
	for i in range(nests.size()):
		var state: Dictionary = nests[i]
		if not bool(state["discovered"]) or bool(state["destroyed"]):
			continue
		var visual := state["node"] as Node2D
		if visual != null and is_instance_valid(visual):
			var distance := player.global_position.distance_to(visual.global_position)
			if distance < closest_distance and distance <= NEST_INTERACT_DISTANCE:
				closest_distance = distance
				closest_attackable = i

		state["cooldown"] = float(state["cooldown"]) - delta
		if float(state["cooldown"]) <= 0.0:
			if _can_spawn_from_nest(state):
				_spawn_from_nest(i)
			state = nests[i]
			state["cooldown"] = float(state["interval"])
		nests[i] = state

	if closest_attackable >= 0:
		var target: Dictionary = nests[closest_attackable]
		nearby_hint = "E: strike %s  (%d/%d)" % [target["name"], int(target["health"]), int(target["max_health"])]
		if Input.is_action_just_pressed("p1_interact") and nest_hit_cooldown <= 0.0:
			nest_hit_cooldown = 0.32
			_damage_nest(closest_attackable)

func _can_spawn_from_nest(state: Dictionary) -> bool:
	if _count_world_enemies() >= MAX_ACTIVE_ENEMIES:
		return false
	var cell: Vector2i = state["cell"]
	if world.astar == null or not world.astar.is_in_bounds(cell.x, cell.y):
		return false
	return not world.astar.get_id_path(cell, BASE_TARGET_CELL).is_empty()

func _spawn_from_nest(index: int) -> void:
	var state: Dictionary = nests[index]
	var zone := int(state["zone"])
	var spawned := int(state["spawned"])
	var type_pool: Array[int]
	match zone:
		1:
			type_pool = [0, 1]
		2:
			type_pool = [1, 2, 3]
		_:
			type_pool = [2, 3, 4]

	var enemy := ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	enemy.global_position = _cell_world_position(state["cell"]) + Vector2((spawned % 3 - 1) * 10.0, 0.0)
	var difficulty := 1 + zone * 2 + artifacts_collected
	if enemy.has_method("initialize"):
		enemy.initialize(difficulty, false, type_pool[spawned % type_pool.size()])
	if enemy.has_method("begin_breach_emergence"):
		enemy.begin_breach_emergence(0.55)
	state["spawned"] = spawned + 1
	nests[index] = state

func _damage_nest(index: int) -> void:
	var state: Dictionary = nests[index]
	state["health"] = int(state["health"]) - 1
	nests[index] = state
	_update_nest_label(index)
	var visual := state["node"] as Node2D
	if visual != null and is_instance_valid(visual):
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector2(1.22, 0.78), 0.08)
		tween.tween_property(visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	if int(state["health"]) <= 0:
		_destroy_nest(index)

func _destroy_nest(index: int) -> void:
	var state: Dictionary = nests[index]
	if bool(state["destroyed"]):
		return
	state["destroyed"] = true
	nests_destroyed += 1
	var visual := state["node"] as Node2D
	if visual != null and is_instance_valid(visual):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visual, "scale", Vector2(1.5, 0.15), 0.28)
		tween.tween_property(visual, "modulate", Color(1, 1, 1, 0), 0.28)
		tween.chain().tween_callback(visual.queue_free)
	state["node"] = null
	nests[index] = state
	if hud and hud.has_method("add_gold"):
		hud.add_gold(10 + int(state["zone"]) * 8)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("%s destroyed. This part of the mine is safer now." % state["name"], 3.5)

func _update_nest_label(index: int) -> void:
	var state: Dictionary = nests[index]
	var label := state["label"] as Label
	if label != null and is_instance_valid(label):
		label.text = "%s\nE TO BREAK  %d/%d" % [String(state["name"]).to_upper(), int(state["health"]), int(state["max_health"])]

func _update_artifact_pickups() -> void:
	for i in range(artifacts.size()):
		var state: Dictionary = artifacts[i]
		if not bool(state["revealed"]) or bool(state["collected"]):
			continue
		var visual := state["node"] as Node2D
		if visual == null or not is_instance_valid(visual):
			continue
		if player.global_position.distance_to(visual.global_position) <= ARTIFACT_PICKUP_DISTANCE:
			_collect_artifact(i)

func _collect_artifact(index: int) -> void:
	var state: Dictionary = artifacts[index]
	if bool(state["collected"]):
		return
	state["collected"] = true
	artifacts_collected += 1
	var visual := state["node"] as Node2D
	if visual != null and is_instance_valid(visual):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visual, "scale", Vector2(2.0, 2.0), 0.32)
		tween.tween_property(visual, "modulate", Color(1, 1, 1, 0), 0.32)
		tween.chain().tween_callback(visual.queue_free)
	state["node"] = null
	artifacts[index] = state

	# Each artifact immediately changes the run instead of being only a key.
	player.strength = int(player.strength) + 1
	player.max_health = int(player.max_health) + 5
	player.health = mini(int(player.max_health), int(player.health) + 5)
	player.base_dig_time = maxf(0.18, float(player.base_dig_time) * 0.92)
	if hud and hud.has_method("show_notice"):
		var suffix := " The bottom seal can now be opened." if artifacts_collected >= REQUIRED_ARTIFACTS else ""
		hud.show_notice("ARTIFACT CLAIMED: %s. Digging and combat power increased.%s" % [state["name"], suffix], 5.0)

func _update_boss_gate() -> void:
	if boss_spawned or _is_solid(BOSS_GATE_CELL):
		return
	if artifacts_collected < REQUIRED_ARTIFACTS:
		if boss_seal == null or not is_instance_valid(boss_seal):
			boss_seal = _create_boss_seal()
			if hud and hud.has_method("show_notice"):
				hud.show_notice("The bottom seal rejects you. Find all three artifacts first.", 4.2)
		nearby_hint = "BOTTOM SEAL: %d/%d artifacts" % [artifacts_collected, REQUIRED_ARTIFACTS]
		return
	_spawn_boss()

func _spawn_boss() -> void:
	boss_spawned = true
	if boss_seal != null and is_instance_valid(boss_seal):
		boss_seal.queue_free()
		boss_seal = null
	for i in range(nests.size()):
		var state: Dictionary = nests[i]
		state["cooldown"] = 99999.0
		nests[i] = state

	boss_node = ENEMY_SCENE.instantiate() as Node2D
	world.add_child(boss_node)
	boss_node.global_position = _cell_world_position(BOSS_GATE_CELL)
	if boss_node.has_method("initialize"):
		boss_node.initialize(12, true, 4)
	if boss_node.has_method("begin_breach_emergence"):
		boss_node.begin_breach_emergence(1.2)
	boss_node.tree_exited.connect(_on_boss_removed)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("THE DEEP GUARDIAN AWAKENS — intercept it before it reaches the core!", 6.0)

func _on_boss_removed() -> void:
	if exploration_complete or world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return
	exploration_complete = true
	if hud and hud.has_method("show_notice"):
		hud.show_notice("THE DEEP GUARDIAN HAS FALLEN. Exploration complete!", 5.0)
	var match_flow := get_node_or_null("/root/MatchFlow")
	if match_flow and match_flow.has_method("_finish_match"):
		match_flow.active_world = world
		match_flow.result_shown = false
		match_flow.call_deferred("_finish_match", true)

func _create_nest_visual(state: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = "ExplorationNest_%s" % String(state["name"]).replace(" ", "_")
	node.global_position = _cell_world_position(state["cell"])
	node.z_index = 8
	world.add_child(node)

	var zone := int(state["zone"])
	var colors := [Color(0.72, 0.23, 0.12, 1), Color(0.62, 0.12, 0.48, 1), Color(0.25, 0.05, 0.42, 1)]
	var core := Polygon2D.new()
	core.polygon = _circle_points(25.0 + zone * 2.0, 14)
	core.color = colors[clampi(zone - 1, 0, colors.size() - 1)]
	node.add_child(core)

	for angle in [0.2, 1.35, 2.55, 3.6, 4.85, 5.7]:
		var tendril := Line2D.new()
		tendril.width = 6.0
		tendril.default_color = Color(core.color, 0.92)
		var direction := Vector2.RIGHT.rotated(float(angle))
		tendril.points = PackedVector2Array([direction * 12.0, direction * 30.0 + direction.orthogonal() * 7.0, direction * 42.0])
		node.add_child(tendril)

	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(0, -7), Vector2(10, 0), Vector2(0, 7)])
	eye.color = Color(1.0, 0.76, 0.18, 1.0)
	node.add_child(eye)

	var label := Label.new()
	label.name = "Status"
	label.position = Vector2(-105, -68)
	label.size = Vector2(210, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	node.add_child(label)

	var tween := create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(1.08, 0.94), 0.75).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE)
	return node

func _create_artifact_visual(state: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = "ExplorationArtifact_%s" % String(state["name"]).replace(" ", "_")
	node.global_position = _cell_world_position(state["cell"])
	node.z_index = 9
	world.add_child(node)

	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(0, -34), Vector2(23, 0), Vector2(0, 34), Vector2(-23, 0)])
	glow.color = Color(0.15, 0.8, 1.0, 0.28)
	node.add_child(glow)
	var crystal := Polygon2D.new()
	crystal.polygon = PackedVector2Array([Vector2(0, -25), Vector2(14, -5), Vector2(9, 20), Vector2(0, 28), Vector2(-10, 18), Vector2(-14, -5)])
	crystal.color = Color(0.28, 0.95, 1.0, 1.0)
	node.add_child(crystal)
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color.WHITE
	line.points = PackedVector2Array([Vector2(0, -22), Vector2(-4, 3), Vector2(3, 20)])
	node.add_child(line)
	var label := Label.new()
	label.text = String(state["name"]).to_upper()
	label.position = Vector2(-90, 38)
	label.size = Vector2(180, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	node.add_child(label)
	var tween := create_tween().set_loops()
	tween.tween_property(node, "position", node.position + Vector2(0, -8), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position", node.position, 0.8).set_trans(Tween.TRANS_SINE)
	return node

func _create_boss_seal() -> Node2D:
	var node := Node2D.new()
	node.name = "BottomArtifactSeal"
	node.global_position = _cell_world_position(BOSS_GATE_CELL)
	node.z_index = 9
	world.add_child(node)
	var ring := Line2D.new()
	ring.width = 7.0
	ring.default_color = Color(0.95, 0.2, 0.12, 0.95)
	var ring_points := _circle_points(33.0, 28)
	ring_points.append(ring_points[0])
	ring.points = ring_points
	node.add_child(ring)
	var lock := Label.new()
	lock.text = "SEALED\n%d/%d ARTIFACTS" % [artifacts_collected, REQUIRED_ARTIFACTS]
	lock.position = Vector2(-90, -26)
	lock.size = Vector2(180, 52)
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_theme_font_size_override("font_size", 14)
	lock.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25, 1.0))
	lock.add_theme_color_override("font_outline_color", Color.BLACK)
	lock.add_theme_constant_override("outline_size", 4)
	node.add_child(lock)
	return node

func _create_objective_ui() -> void:
	objective_layer = CanvasLayer.new()
	objective_layer.layer = 25
	add_child(objective_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 96)
	panel.custom_minimum_size = Vector2(370, 0)
	objective_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "EXPLORATION MODE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0, 1.0))
	stack.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	stack.add_child(status_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	stack.add_child(hint_label)

func _update_objective_ui() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var depth := maxi(_player_cell().y, 0)
	var zone := _depth_zone(depth)
	status_label.text = "Depth %d  •  %s\nArtifacts %d/%d  •  Nests destroyed %d/%d" % [depth, zone, artifacts_collected, REQUIRED_ARTIFACTS, nests_destroyed, nests.size()]
	if exploration_complete:
		hint_label.text = "The Deep Guardian is defeated."
	elif boss_spawned:
		hint_label.text = "BOSS ACTIVE — protect the core."
	elif not nearby_hint.is_empty():
		hint_label.text = nearby_hint
	elif artifacts_collected >= REQUIRED_ARTIFACTS:
		hint_label.text = "All artifacts found. Reach the bottom seal."
	else:
		hint_label.text = "Dig deeper. Listen for nests and artifact resonance."

func _depth_zone(depth: int) -> String:
	if depth < 10:
		return "SHALLOW MINE"
	if depth < 20:
		return "LOWER CAVERNS"
	return "THE DEEP"

func _count_world_enemies() -> int:
	var count := 0
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_value as Node
		if enemy != null and is_instance_valid(enemy) and world.is_ancestor_of(enemy):
			count += 1
	return count

func _player_cell() -> Vector2i:
	return block_layer.local_to_map(block_layer.to_local(player.global_position))

func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _is_solid(cell: Vector2i) -> bool:
	return block_layer.get_cell_source_id(cell) != -1

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))

func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * radius)
	return points
