@tool
extends McpTestSuite

func suite_name() -> String:
	return "upgrade_tree_ui"

func _source() -> String:
	var source := FileAccess.get_file_as_string("res://upgrade_menu.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "Upgrade-menu source must compile")
	return source

func test_tree_is_large_scrollable_and_leaves_the_world_visible() -> void:
	var source := _source()
	assert_true(source.contains("SINGLE_MENU_MAX_SCREEN_WIDTH_RATIO := 0.70"), "Single-player graph should use a large readable portion of the viewport")
	assert_true(source.contains("UPGRADE_TREE_WORLD_STRIP := 260.0"), "Desktop layout should reserve a live-world strip")
	assert_true(source.contains("upgrade_tree_shell = PanelContainer.new()"), "Upgrade graph should use a dedicated shell")
	assert_true(source.contains("upgrade_tree_scroll = ScrollContainer.new()"), "Large graphs should remain scrollable")
	assert_true(source.contains("upgrade_tree_canvas.custom_minimum_size = Vector2(860.0"), "Canvas height should expand from graph content")
	assert_true(source.contains("_layout_upgrade_graph_branch"), "Gameplay groups should use automatic graph branches")
	assert_true(source.contains("_create_tree_connector"), "Real dependencies should have visible connectors")
	assert_true(source.contains("upgrade_tree_stat_bar.name = \"QuickStats\""), "Attribute upgrades should stay fixed outside the graph")
	assert_true(source.contains("\"title\": \"HUD MODULES\""), "HUD modules should own the health and information branches")
	assert_true(source.contains("\"title\": \"EXPLORATION\""), "Exploration should remain a named dependency branch")
	assert_true(source.contains("\"title\": \"FACTION\""), "Faction should remain a named dependency branch")
	assert_true(source.contains("button.flat = true"), "Graph nodes should not inherit oversized global button textures")

func test_tree_is_icon_first_and_uses_compact_cost_badges() -> void:
	var source := _source()
	assert_true(source.contains("currency_icon.name = \"CurrencyIcon\""), "Each node should have a currency icon")
	assert_true(source.contains("currency_icon.texture = GEM_ICON_TEXTURE if currency == \"gems\" else GOLD_ICON_TEXTURE"), "Currency badges should distinguish gems and gold")
	assert_true(source.contains("cost_label.text = \"—\" if future_locked or owned else str(cost)"), "Cost badges should stay numeric and disappear for owned foundation nodes")
	assert_true(source.contains("state_label.text = \"✓\""), "Owned nodes should use a compact state mark")
	assert_true(source.contains("state_label.text = \"🔒\""), "Locked nodes should use a compact lock mark")
	assert_true(source.contains("upgrade_tree_detail.text = \"%s — %s\""), "Long descriptions should live in the detail panel")
	assert_true(source.contains("card_background.name = \"CardBackground\""), "Each node should own an explicit readable background")
	assert_true(source.contains("hud_health.svg") and source.contains("base_health.svg") and source.contains("minimap.svg"), "Authored SVG upgrade icons should be used instead of raster fallbacks")
	assert_true(source.contains("func _load_upgrade_icon_texture") and source.contains("AtlasTexture.new()"), "Game spritesheets should be cropped to a single readable frame")

func test_tree_preserves_costs_owned_states_and_dependencies() -> void:
	var source := _source()
	assert_true(source.contains("upgrade_tree_resources.text = \"Gems %d   Gold %d\""), "Tree header should show live currencies")
	assert_true(source.contains("dependency_locked = not minimap_unlocked"), "Enemy Sight should require Minimap")
	assert_true(source.contains("dependency_locked = not healthbar_unlocked"), "Hero health actions should require Hero HP")
	assert_true(source.contains("dependency_locked = not base_health_unlocked"), "Base health actions should require Base HP")
	assert_true(source.contains("func _is_upgrade_tree_node_owned"), "Tree should map unlock flags into persistent node states")
	assert_true(source.contains("minimap_unlocked = true"), "Existing Minimap purchase behavior must remain intact")
	assert_true(source.contains("minimap_upgraded = true"), "Existing Enemy Sight purchase behavior must remain intact")

func test_open_tree_frames_world_and_creates_a_safe_solo_planning_pause() -> void:
	var source := _source()
	assert_true(source.contains("call_deferred(\"_shift_camera_for_upgrade_tree\")"), "Opening should frame gameplay in the visible world strip")
	assert_true(source.contains("var desired_player_x: float = shell_right + visible_strip_width * 0.48"), "Player framing should target the world strip")
	assert_true(source.contains("upgrade_camera_original_offset"), "Camera movement should retain its original offset")
	assert_true(source.contains("_restore_camera_after_upgrade_tree()"), "Closing should restore the gameplay camera")
	assert_true(source.contains("if player: player.can_move = false"), "Opening should stop direct player movement")
	assert_true(source.contains("if player: player.can_move = true"), "Closing should restore player movement")
	assert_true(source.contains("process_mode = Node.PROCESS_MODE_ALWAYS"), "The planning UI must remain interactive while solo gameplay is paused")
	assert_true(source.contains("set_meta(\"paused_single_player_gameplay\""), "The menu should remember whether it owns the solo pause")
	assert_true(source.contains("get_tree().paused = true"), "Solo players need time to read upgrade choices without taking hidden damage")
	assert_true(source.contains("get_tree().paused = false"), "Closing the planning menu should resume gameplay")
	assert_true(source.contains("_pulse_upgrade_button(tree_button)"), "Purchased nodes should still pulse visibly")
	assert_true(source.contains("_spawn_stat_upgrade_particles(color)"), "Upgrade feedback should remain authored in world space")
