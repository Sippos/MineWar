@tool
extends McpTestSuite

func suite_name() -> String:
	return "upgrade_tree_layout"

func _source() -> String:
	var source := FileAccess.get_file_as_string("res://upgrade_menu.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "Upgrade menu source must compile")
	return source

func test_upgrade_menu_builds_a_graph_driven_scrollable_tree() -> void:
	var source := _source()
	assert_true(source.contains("const UPGRADE_TREE_STRIP_RATIO := 0.56"), "Single player should draw the board as a bottom command strip")
	assert_true(source.contains("upgrade_tree_shell.position = Vector2(margin, view_size.y - height - margin)"), "The command strip should anchor to the bottom of the screen")
	assert_true(source.contains("func _branch_band_width"), "Branches should sit side by side in their own vertical bands")
	assert_true(source.contains("const UPGRADE_TREE_DEPTH_STEP := 152.0"), "The depth step must clear a full card so children never overlap their parent")
	assert_true(source.contains("upgrade_tree_scroll = ScrollContainer.new()"), "Upgrade graph should remain scrollable")
	assert_true(source.contains("func _upgrade_graph_definition()"), "Upgrade dependencies should be defined as graph data")
	assert_true(source.contains("func _layout_upgrade_graph_branch"), "Graph branches should be positioned automatically")
	assert_true(source.contains("func _graph_leaf_count"), "Parallel branch spacing should be derived from leaf counts")
	assert_true(source.contains("func _layout_upgrade_graph_node"), "Graph nodes should be laid out recursively")
	assert_true(source.contains("\"children\": ["), "Graph definitions should support parallel child paths")
	assert_true(source.contains("upgrade_tree_stat_bar.name = \"QuickStats\""), "Stat upgrades should remain in a fixed quick-access strip")
	assert_true(source.contains("Tree_%s"), "Runtime upgrade cards should have stable node names")

func test_upgrade_tree_preserves_real_dependencies_and_live_world_context() -> void:
	var source := _source()
	assert_true(source.contains("id == \"UpgradeMinimap\""), "Enemy Sight should remain dependent on Minimap")
	assert_true(source.contains("id == \"HealPlayer\" or id == \"UpgradeMaxHealth\""), "Hero health upgrades should require the Hero HP module")
	assert_true(source.contains("id == \"RepairBase\" or id == \"UpgradeBaseHealth\""), "Base health upgrades should require the Base HP module")
	assert_true(source.contains("currency_icon.texture = GEM_ICON_TEXTURE if currency == \"gems\" else GOLD_ICON_TEXTURE"), "Costs should use currency sprites")
	assert_true(source.contains("cost_label.text = \"—\" if future_locked or owned else str(cost)"), "Cards should show numeric costs and hide costs for owned foundation nodes")
	assert_true(source.contains("_shift_camera_for_upgrade_tree"), "Opening the tree should shift the live world into view")
	assert_true(source.contains("desired_player_y"), "Camera shift should lift the hero into the clear band above the strip")
	assert_true(source.contains("_restore_camera_after_upgrade_tree"), "Closing should restore the original camera offset")
	assert_true(source.contains("_play_stat_upgrade_effect"), "Existing world-space upgrade VFX should remain wired")
	assert_true(source.contains("if player: player.can_move = false"), "Opening should stop player movement without pausing the world")
	assert_true(source.contains("if player: player.can_move = true"), "Closing should restore player movement")
