@tool
extends McpTestSuite

func suite_name() -> String:
	return "result_menu_visuals"

func _source(path: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "%s must compile" % path)
	return source

func test_defeat_uses_one_result_flow_with_real_destinations() -> void:
	var flow_source := _source("res://match_flow.gd")
	var hud_source := _source("res://hud.gd")
	assert_true(flow_source.contains("func request_defeat(world: Node)"), "Base destruction should enter MatchFlow directly")
	assert_true(hud_source.contains("match_flow.request_defeat(get_parent())"), "HUD should not build a competing defeat overlay")
	assert_true(flow_source.contains("Change Loadout"), "The result screen should offer the actual hero selector")
	assert_true(flow_source.contains("Workshop"), "The preparation chamber action should be named honestly")
	assert_true(flow_source.contains("Main Menu"), "The player should be able to leave a completed run")
	assert_true(flow_source.contains("selector.setup(0, \"solo_retry\")"), "Change Loadout should open the existing retry selector")

func test_result_screen_uses_hero_and_stat_sprites() -> void:
	var flow_source := _source("res://match_flow.gd")
	assert_true(flow_source.contains("Strenght.png"), "Strength should use its authored sprite")
	assert_true(flow_source.contains("Agility.png"), "Agility should use its authored sprite")
	assert_true(flow_source.contains("Int.png"), "Intelligence should use its authored sprite")
	assert_true(flow_source.contains("HERO_PORTRAIT_TEXTURES"), "The result screen should show a clean hero portrait")
	assert_true(flow_source.contains("GEM_TEXTURE"), "Banked gems should use their resource sprite")
	assert_true(flow_source.contains("GOLD_TEXTURE"), "Banked gold should use its resource sprite")

func test_loadout_changes_persist_for_the_next_retry() -> void:
	var selector_source := _source("res://hero_selection_menu.gd")
	assert_true(selector_source.contains("Global.set_run_loadout(available_heroes[p1_index], Global.selected_base_id)"), "Retry selection should update the persistent run loadout")
