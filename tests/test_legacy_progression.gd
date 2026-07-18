@tool
extends McpTestSuite

func suite_name() -> String:
	return "legacy_progression"

func _source(path: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "%s must compile" % path)
	return source

func test_runs_award_and_persist_legacy_ore() -> void:
	var global_source := _source("res://global.gd")
	var flow_source := _source("res://match_flow.gd")
	assert_true(global_source.contains("var legacy_ore := 0"), "Legacy ore should be persistent global progression")
	assert_true(global_source.contains("func award_run_legacy_ore"), "Every completed run should award legacy ore")
	assert_true(global_source.contains("ceil(float(maxi(wave_reached, 1)) / 3.0)"), "Deeper runs should award more ore")
	assert_true(global_source.contains("if victory:\n\t\treward += 3"), "Victory should grant a meaningful ore bonus")
	assert_true(global_source.contains("\"legacy_ore\": legacy_ore"), "Legacy ore should be stored in the save")
	assert_true(global_source.contains("\"permanent_upgrade_levels\": permanent_upgrade_levels"), "Permanent ranks should be stored in the save")
	assert_true(flow_source.contains("Global.award_run_legacy_ore(wave_reached, victory)"), "The actual result flow should award the currency")
	assert_true(flow_source.contains("Global.mark_first_level_beaten()"), "Victory should trigger the intended hero unlock progression")

func test_preparation_hub_has_physical_permanent_upgrade_pads() -> void:
	var hub_source := _source("res://scripts/systems/preparation/preparation_hub.gd")
	assert_true(hub_source.contains("\"reinforced_core\""), "The workshop should offer permanent base durability")
	assert_true(hub_source.contains("\"starter_cache\""), "The workshop should offer a stronger run opening")
	assert_true(hub_source.contains("\"miners_harness\""), "The workshop should offer permanent carrying utility")
	assert_true(hub_source.contains("player.position.distance_to(pad_position)"), "Pads should be selected by physically approaching them")
	assert_true(hub_source.contains("event.is_action_pressed(\"p1_interact\")"), "Nearby pads should use the normal in-world interaction input")
	assert_true(hub_source.contains("Global.purchase_permanent_upgrade(upgrade_id)"), "The physical workshop should spend the persistent currency")
	assert_true(hub_source.contains("Permanent bonus active next run"), "Purchases should clearly explain when their effect applies")

func test_first_stronghold_is_compact_and_expands_after_first_run() -> void:
	var world_source := _source("res://scripts/systems/preparation/preparation_fast_world.gd")
	var controller_source := _source("res://scripts/systems/single_player_world_controller.gd")
	var selector_source := _source("res://scripts/systems/preparation/in_world_hero_selector.gd")
	assert_true(world_source.contains("COMPACT_HUB_ROOM_X_MIN"), "Fresh saves should use a compact starter room")
	assert_true(world_source.contains("var expanded_stronghold := bool(Global.first_level_beaten)"), "The stronghold should expand after the first completed run")
	assert_true(world_source.contains("if expanded_stronghold:"), "Additional mode routes should be gated behind the expanded stronghold")
	assert_true(controller_source.contains("if not Global.first_level_beaten or world == null or player == null"), "The practice cart and peon should stay hidden during the first run")
	assert_true(controller_source.contains("var zoom_value := 0.82 if Global.first_level_beaten else 1.14"), "The first room should use a closer camera framing")
	assert_true(selector_source.contains("if not Global.first_level_beaten:"), "The hero gallery should appear only after the first run")

func test_permanent_bonuses_apply_to_runs_and_results_remain_normalized() -> void:
	var world_source := _source("res://scripts/systems/world_generation/world.gd")
	var player_source := _source("res://player.gd")
	var flow_source := _source("res://match_flow.gd")
	assert_true(world_source.contains("Global.get_permanent_base_health_bonus()"), "Core ranks should increase starting base durability")
	assert_true(world_source.contains("Global.get_permanent_starting_gems()"), "Cache ranks should grant starting gems")
	assert_true(player_source.contains("get_permanent_carry_bonus"), "Harness ranks should increase free carrying")
	assert_true(flow_source.contains("float(base.get(\"health\")) / maxf(float(base.get(\"max_health\")), 1.0) * 100.0"), "Result integrity should be a percentage of upgraded maximum health")
	assert_true(flow_source.contains("Legacy ore earned"), "The result screen should explain the meta reward")
	assert_true(flow_source.contains("Legacy ore total"), "The result screen should show progress toward workshop purchases")
