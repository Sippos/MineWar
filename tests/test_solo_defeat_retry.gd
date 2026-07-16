@tool
extends McpTestSuite

func suite_name() -> String:
	return "solo_defeat_retry"

func _read_source(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _assert_source_compiles(path: String) -> String:
	var source := _read_source(path)
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "%s must compile after the retry-flow change" % path)
	return source

func test_retry_selector_contract_keeps_player_in_solo_flow() -> void:
	var source := _assert_source_compiles("res://hero_selection_menu.gd")
	assert_true(source.contains("func setup(mode: int, context: String = \"menu\")"), "The selector should accept a retry context without breaking existing menu calls")
	assert_true(source.contains("available_heroes.find(Global.hero_p1)"), "Retry setup should begin on the hero used in the defeated run")
	assert_true(source.contains("Choose Hero & Matching Base"), "The retry selector should explain that the hero changes the matching base")
	assert_true(source.contains("Retry from Surface"), "The retry action should return to the surface start instead of the main menu")
	assert_true(source.contains("get_tree().paused = false"), "Starting a retry must unpause before loading the fresh run")

func test_game_over_contract_opens_retry_setup_at_the_surface() -> void:
	var source := _assert_source_compiles("res://hud.gd")
	assert_true(source.contains("Change Hero / Base & Retry"), "The primary defeat action should no longer be Back to Main Menu")
	assert_true(source.contains("func _open_solo_retry_setup()"), "The HUD should own a dedicated solo retry transition")
	assert_true(source.contains("player.global_position = base.global_position + Vector2(0, 32)"), "Opening retry setup should bring the camera/player back to the surface base")
	assert_true(source.contains("selector.setup(0, \"solo_retry\")"), "Defeat should reopen the existing single-player selector in retry mode")
	assert_true(source.contains("selector.process_mode = Node.PROCESS_MODE_ALWAYS"), "The selector must remain interactive while the defeated run is paused")
