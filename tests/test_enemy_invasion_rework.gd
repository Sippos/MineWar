@tool
extends McpTestSuite

func suite_name() -> String:
	return "enemy_invasion_rework"

func _source(path: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "%s must compile" % path)
	return source

func test_waves_use_prepared_persistent_breaches_instead_of_farthest_player_tunnel() -> void:
	var source := _source("res://scripts/systems/world_generation/world.gd")
	assert_true(source.contains("const SURFACE_BREACH_CELLS"), "The mine should always have fair exterior fallback entrances")
	assert_true(source.contains("const BREACH_SITE_WAVE_LIFETIME := 2"), "A breach should persist long enough for route-building decisions")
	assert_true(source.contains("_prepare_breach_for_wave(wave_number)"), "A breach must be selected before the wave spawns")
	assert_true(source.contains("var target_cell := current_breach_cell"), "Wave spawning should use the announced breach")
	var spawn_start := source.find("func spawn_wave")
	var spawn_end := source.find("func update_front_wall", spawn_start)
	var spawn_source := source.substr(spawn_start, spawn_end - spawn_start)
	assert_false(spawn_source.contains("get_farthest_open_cell"), "The wave must not recalculate a spawn at the player's newest tunnel endpoint")

func test_dynamic_breaches_reject_recent_or_nearby_digging() -> void:
	var source := _source("res://scripts/systems/world_generation/world.gd")
	assert_true(source.contains("BREACH_MIN_PLAYER_WORLD_DISTANCE := 460.0"), "Enemies should not materialize directly beside the player")
	assert_true(source.contains("BREACH_RECENT_DIG_GRACE_MSEC := 8000"), "Freshly opened tunnel tips should receive a safety grace period")
	assert_true(source.contains("grid_distance < BREACH_MIN_PLAYER_GRID_DISTANCE"), "Selection should also use tunnel-cell distance")
	assert_true(source.contains("_is_dynamic_breach_endpoint"), "Underground breaches should come from readable tunnel endpoints, not cavern centers")
	assert_true(source.contains("_carve_surface_breach_corridors"), "A one-corridor mine should fall back to stable side entrances")

func test_wide_cavern_movement_has_edge_affinity_lanes_and_separation() -> void:
	var world_source := _source("res://scripts/systems/world_generation/world.gd")
	var enemy_source := _source("res://enemy.gd")
	assert_true(world_source.contains("weight *= 2.4"), "Fully open cavern centers should cost more than floors and tunnel edges")
	assert_true(world_source.contains("get_enemy_open_space_factor"), "Enemies should detect when they enter a wide room")
	assert_true(enemy_source.contains("OPEN_SPACE_LANE_STRENGTH"), "Wide rooms should create small individual movement lanes")
	assert_true(enemy_source.contains("_calculate_separation_velocity"), "Groups should spread instead of stacking into one straight line")
	assert_true(enemy_source.contains("_update_stuck_tracking"), "Enemies should recover after topology or crowding blocks a route")
	assert_true(enemy_source.contains("begin_breach_emergence"), "Spawns should visibly emerge rather than pop into existence")

func test_breach_is_visible_even_when_offscreen() -> void:
	var hud_source := _source("res://hud.gd")
	assert_true(hud_source.contains("func set_breach_target"), "The world should be able to announce the selected breach to the HUD")
	assert_true(hud_source.contains("func _update_breach_direction_cue"), "Deep players should receive an edge cue toward the next breach")
	assert_true(hud_source.contains("breach_direction_label.text") and hud_source.contains("wave_number"), "The cue should identify which wave the entrance belongs to")
