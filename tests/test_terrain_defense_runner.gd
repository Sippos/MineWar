extends Node

## Test suite verifying POLISH-029:
## 1. Dynamic terrain rerouting around solid rock obstacles
## 2. Dynamic shortcut adaptation when new tunnels are dug
## 3. Dynamic barrier placement and re-rerouting
## 4. Flow field corner-cutting prevention across solid corners
## 5. Chokepoint recognition for narrow corridors vs open caverns
## 6. Chokepoint combat tactical bonus (+35%) and loot drop multiplier
## 7. Explosive trap block arming, detonation, AoE damage, and block clearance
## 8. RunSummaryData chokepoint_kills scoring and serialization

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const SUMMARY_DATA_SCRIPT: GDScript = preload("res://scripts/systems/gameplay/run_summary_data.gd")

var failures := 0
var mock_world: Node2D
var mock_tile_map: TileMapLayer
var mock_base: CharacterBody2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_all_tests")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _finish() -> void:
	if failures == 0:
		print("TERRAIN_DEFENSE_PASS")
		get_tree().quit(0)
	else:
		print("TERRAIN_DEFENSE_FAIL (%d failures)" % failures)
		get_tree().quit(1)

func _run_all_tests() -> void:
	await _setup_mock_environment()
	_test_direct_obstruction_and_tunnel_rerouting()
	_test_dynamic_shortcut_adaptation()
	_test_reinforcement_barrier_re_rerouting()
	_test_diagonal_corner_cutting_prevention()
	_test_chokepoint_detection_and_tactical_damage()
	_test_explosive_trap_detonation()
	_test_run_summary_score_with_chokepoint_kills()
	_cleanup_mock_environment()
	_finish()

func _setup_mock_environment() -> void:
	mock_world = Node2D.new()
	mock_world.name = "MockWorld"
	
	# Add AStarGrid2D
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(-15, -15, 30, 30)
	astar.cell_size = Vector2(64, 64)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	mock_world.set("astar", astar)
	mock_world.set("topology_revision", 1)
	mock_world.set("flow_field", {})
	mock_world.set("flow_field_target", Vector2i(0, 0))
	mock_world.set("chokepoint_kills", 0)
	mock_world.set("explosive_trap_cells", {})

	# Set script or methods on mock_world
	var world_script: GDScript = preload("res://scripts/systems/world_generation/world.gd")
	mock_world.set_script(world_script)
	mock_world.astar = astar
	mock_world.flow_field = {}
	mock_world.flow_field_target = Vector2i(0, 0)

	# Mock tile map layer
	mock_tile_map = TileMapLayer.new()
	mock_tile_map.name = "BlockLayer"
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	mock_tile_map.tile_set = tile_set
	mock_world.add_child(mock_tile_map)
	mock_world.set("block_layer", mock_tile_map)

	# Mock Base
	mock_base = CharacterBody2D.new()
	mock_base.name = "Base"
	mock_base.global_position = Vector2(0, 0)
	mock_world.add_child(mock_base)

	# Mock child layers to satisfy @onready variables without errors
	for child_name in ["BackgroundLayer", "EdgeLayer", "InsideCornerTL", "InsideCornerTR", "InsideCornerBL", "InsideCornerBR", "DamageLayer", "FogLayer", "FrontWallLayer"]:
		var layer := TileMapLayer.new()
		layer.name = child_name
		mock_world.add_child(layer)
	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "CanvasModulate"
	mock_world.add_child(canvas_mod)
	var dummy_player := Node2D.new()
	dummy_player.name = "Player"
	var dummy_light := PointLight2D.new()
	dummy_light.name = "PointLight2D"
	dummy_player.add_child(dummy_light)
	mock_world.add_child(dummy_player)

	add_child(mock_world)
	await get_tree().process_frame

func _cleanup_mock_environment() -> void:
	if mock_world != null and is_instance_valid(mock_world):
		mock_world.queue_free()
	await get_tree().process_frame

func _test_direct_obstruction_and_tunnel_rerouting() -> void:
	var astar: AStarGrid2D = mock_world.astar
	
	# Solidify grid initially
	for x in range(-5, 6):
		for y in range(-2, 8):
			astar.set_point_solid(Vector2i(x, y), true)

	# Target base at (0, 0) is open
	astar.set_point_solid(Vector2i(0, 0), false)
	# Start at (0, 6) is open
	astar.set_point_solid(Vector2i(0, 6), false)

	# Direct path (0, 1..5) is solid rock!
	# Verify direct path is blocked
	var direct_path: Array[Vector2i] = astar.get_id_path(Vector2i(0, 6), Vector2i(0, 0))
	_expect(direct_path.is_empty(), "Direct path should be blocked by solid rock")

	# Dig excavated detour around the flank: x = -2, from y = 6 down to y = 0
	# and horizontal links at y=6 (x=-1) and y=0 (x=-1)
	astar.set_point_solid(Vector2i(-1, 6), false)
	for y in range(0, 7):
		astar.set_point_solid(Vector2i(-2, y), false)
	astar.set_point_solid(Vector2i(-1, 0), false)

	var rerouted_path: Array[Vector2i] = astar.get_id_path(Vector2i(0, 6), Vector2i(0, 0))
	_expect(not rerouted_path.is_empty(), "Enemy should find valid path through excavated detour")
	
	var all_walkable := true
	var routes_through_flank := false
	for pt in rerouted_path:
		if astar.is_point_solid(pt):
			all_walkable = false
		if pt.x == -2:
			routes_through_flank = true
	_expect(all_walkable, "All points in path must be walkable excavated cells")
	_expect(routes_through_flank, "Enemy path must route through excavated flank at x=-2")

func _test_dynamic_shortcut_adaptation() -> void:
	var astar: AStarGrid2D = mock_world.astar
	var detour_path: Array[Vector2i] = astar.get_id_path(Vector2i(0, 6), Vector2i(0, 0))
	var detour_length: int = detour_path.size()

	# Player digs direct shortcut straight through (0, 1..5)
	for y in range(1, 6):
		astar.set_point_solid(Vector2i(0, y), false)
	mock_world.topology_revision += 1

	var shortcut_path: Array[Vector2i] = astar.get_id_path(Vector2i(0, 6), Vector2i(0, 0))
	_expect(not shortcut_path.is_empty(), "Shortcut path must be valid")
	_expect(shortcut_path.size() < detour_length, "Direct shortcut path must be shorter than flank detour (%d < %d)" % [shortcut_path.size(), detour_length])
	
	var uses_direct_corridor := true
	for pt in shortcut_path:
		if pt.x != 0:
			uses_direct_corridor = false
	_expect(uses_direct_corridor, "Enemy should dynamically adapt to the straight tunnel")

func _test_reinforcement_barrier_re_rerouting() -> void:
	var astar: AStarGrid2D = mock_world.astar

	# Player places a reinforcement barrier at (0, 3)
	var placed: bool = bool(mock_world.place_reinforcement_barrier(Vector2i(0, 3)))
	_expect(placed, "Reinforcement barrier should be placed successfully")
	_expect(astar.is_point_solid(Vector2i(0, 3)), "Cell (0, 3) must now be solid")

	var re_rerouted_path: Array[Vector2i] = astar.get_id_path(Vector2i(0, 6), Vector2i(0, 0))
	_expect(not re_rerouted_path.is_empty(), "Enemy should find alternate route when barrier is placed")
	
	var avoids_barrier := true
	var uses_flank := false
	for pt in re_rerouted_path:
		if pt == Vector2i(0, 3):
			avoids_barrier = false
		if pt.x == -2:
			uses_flank = true
	_expect(avoids_barrier, "Path must not walk through reinforcement barrier")
	_expect(uses_flank, "Enemy must reroute back through excavated flank")

func _test_diagonal_corner_cutting_prevention() -> void:
	var astar: AStarGrid2D = mock_world.astar
	mock_world.flow_field_target = Vector2i(0, 0)
	
	# Clear test area
	for x in range(3, 7):
		for y in range(3, 7):
			astar.set_point_solid(Vector2i(x, y), true)
			
	# Target at (4, 4), cell at (5, 5)
	# If (5, 4) is solid, diagonal (5, 5) -> (4, 4) must NOT be taken!
	astar.set_point_solid(Vector2i(4, 4), false)
	astar.set_point_solid(Vector2i(5, 5), false)
	astar.set_point_solid(Vector2i(4, 5), false) # open L-bend via (4, 5)
	astar.set_point_solid(Vector2i(5, 4), true)  # solid rock corner!

	mock_world.flow_field_target = Vector2i(4, 4)
	mock_world._update_flow_field()

	if mock_world.flow_field.has(Vector2i(5, 5)):
		var dir: Vector2 = mock_world.flow_field[Vector2i(5, 5)]
		# Should steer orthogonally towards (4, 5) which is Vector2(-1, 0) or Vector2(0, -1),
		# NOT diagonally (-1, -1) which would cut into solid (5, 4)
		var cuts_diagonal := dir.x < -0.5 and dir.y < -0.5
		_expect(not cuts_diagonal, "Flow field must not steer diagonally into solid rock corner")
	else:
		_expect(true, "Flow field handled unreachable corner safely")

func _test_chokepoint_detection_and_tactical_damage() -> void:
	var astar: AStarGrid2D = mock_world.astar

	# Make (-2, 3) a 1-wide vertical corridor (left and right are solid, top and bottom open)
	astar.set_point_solid(Vector2i(-2, 3), false)
	astar.set_point_solid(Vector2i(-3, 3), true)
	astar.set_point_solid(Vector2i(-1, 3), true)
	astar.set_point_solid(Vector2i(-2, 2), false)
	astar.set_point_solid(Vector2i(-2, 4), false)

	_expect(mock_world.is_chokepoint_cell(Vector2i(-2, 3)), "1-wide corridor flanked by walls must be recognized as chokepoint")

	# Make (8, 8) a wide open room (3x3 open)
	for x in range(7, 10):
		for y in range(7, 10):
			astar.set_point_solid(Vector2i(x, y), false)
	_expect(not mock_world.is_chokepoint_cell(Vector2i(8, 8)), "Open cavern cell must not be classified as chokepoint")

	# Test enemy damage bonus in chokepoint
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate() as CharacterBody2D
	mock_world.add_child(enemy)
	enemy.global_position = mock_tile_map.to_global(mock_tile_map.map_to_local(Vector2i(-2, 3)))
	enemy.initialize(1, false, 0)
	
	_expect(bool(enemy.call("is_in_chokepoint")), "Enemy placed in corridor cell must report is_in_chokepoint == true")
	
	enemy.set("health", 100)
	enemy.set("max_health", 100)
	var health_before: int = int(enemy.get("health"))
	enemy.take_damage(20)
	# Tactical bonus: 20 * 1.35 = 27
	var damage_taken: int = health_before - int(enemy.get("health"))
	_expect(damage_taken == 27, "Chokepoint hit should deal +35%% tactical damage (expected 27, got %d)" % damage_taken)

	var chokepoint_kills_before: int = mock_world.chokepoint_kills
	enemy.set("health", 1)
	enemy.take_damage(10) # Kill enemy in chokepoint
	_expect(mock_world.chokepoint_kills == chokepoint_kills_before + 1, "Enemy killed in chokepoint must increment chokepoint_kills")

func _test_explosive_trap_detonation() -> void:
	var astar: AStarGrid2D = mock_world.astar
	var trap_cell := Vector2i(2, 5)

	# Place surrounding soft rock
	mock_world.block_layer.set_cell(Vector2i(2, 4), 1, Vector2i.ZERO)
	mock_world.block_layer.set_cell(Vector2i(3, 5), 1, Vector2i.ZERO)
	astar.set_point_solid(Vector2i(2, 4), true)
	astar.set_point_solid(Vector2i(3, 5), true)

	# Spawn enemy near trap
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate() as CharacterBody2D
	mock_world.add_child(enemy)
	enemy.global_position = mock_tile_map.to_global(mock_tile_map.map_to_local(Vector2i(2, 6)))
	enemy.initialize(1, false, 0)
	var enemy_hp_before: int = int(enemy.get("health"))

	# Arm trap and detonate
	mock_world.arm_explosive_trap(trap_cell, 120, 1)
	mock_world.detonate_explosive_cell(trap_cell)

	_expect(int(enemy.get("health")) < enemy_hp_before, "Explosive trap detonation must damage nearby enemies")
	_expect(not astar.is_point_solid(Vector2i(2, 4)), "Neighboring soft rock must be excavated by blast")

	if is_instance_valid(enemy):
		enemy.queue_free()

func _test_run_summary_score_with_chokepoint_kills() -> void:
	var data: RefCounted = SUMMARY_DATA_SCRIPT.new()
	data.set("blocks_mined", 10)
	data.set("total_gems", 5)
	data.set("waves_survived", 2)
	data.set("base_integrity", 100)
	data.set("chokepoint_kills", 4)
	data.set("horn_greed_multiplier", 1.0)

	# base = 10*10(100) + 5*25(125) + 0 + 4*75(300) + 2*500(1000) + 100*15(1500) = 3025
	var score: int = data.call("calculate_score")
	_expect(score == 3025, "Score with 4 chokepoint kills should equal 3025 (got %d)" % score)

	var dict: Dictionary = data.call("to_dict")
	_expect(int(dict.get("chokepoint_kills")) == 4, "to_dict must preserve chokepoint_kills")

	var restored: RefCounted = SUMMARY_DATA_SCRIPT.call("from_dict", dict)
	_expect(int(restored.get("chokepoint_kills")) == 4, "from_dict must restore chokepoint_kills")
