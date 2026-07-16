@tool
extends McpTestSuite

func suite_name() -> String:
	return "hud_module_layout"

func _source() -> String:
	var source := FileAccess.get_file_as_string("res://hud.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "HUD source must compile")
	return source

func test_semantic_hud_anchors_match_the_gameplay_layout() -> void:
	var source := _source()
	assert_true(source.contains("base_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)"), "Base sprite should anchor to the top-right")
	assert_true(source.contains("PlayerLabel\", player_health_bar, 82.0, false"), "Player health should stay beneath the top-left player cluster")
	assert_true(source.contains("BaseLabel\", base_health_bar, 108.0, true"), "Base health should sit directly beneath the base sprite")
	assert_true(source.contains("wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)"), "Wave timer should use the top middle-right anchor")
	assert_true(source.contains("xp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)"), "XP should remain bottom-center")
	assert_true(source.contains("cave_reward_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)"), "Large item rewards should stay bottom-left")
	assert_true(source.contains("base_status_label.visible = false"), "Base status should use sprite and frame color without status text")

func test_health_and_progress_bars_use_compact_visual_treatment() -> void:
	var source := _source()
	assert_true(source.contains("bar.size = Vector2(module_width, 22.0)"), "Health bars should use a compact 22-pixel height")
	assert_true(source.contains("value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER"), "Health values should be centered inside the bars")
	assert_true(source.contains("_style_hud_progress_bar(xp_bar"), "XP should use the shared progress-bar treatment")
	assert_true(source.contains("_style_hud_progress_bar(wave_bar"), "Wave progress should use the shared progress-bar treatment")
	assert_true(source.contains("var compact := viewport_size.x < 760.0"), "HUD should retain a compact breakpoint")
	assert_true(source.contains("get_tree().root.size_changed.connect(_relayout_unlocked_hud)"), "HUD should relayout on viewport changes")

func test_information_modules_are_tutorial_assistance_not_free_ownership() -> void:
	var world_source := FileAccess.get_file_as_string("res://scripts/systems/world_generation/world.gd")
	var upgrade_source := FileAccess.get_file_as_string("res://upgrade_menu.gd")
	assert_true(world_source.contains("if onboarding_active and hud:"), "The complete information HUD should only be exposed during onboarding")
	assert_true(world_source.contains("Tutorial HUD offline. Restore health, stats, XP, and wave modules at the base."), "Later runs should explain why information modules disappeared")
	assert_true(upgrade_source.contains("var healthbar_unlocked = false"), "Hero-health information should remain a purchasable module")
	assert_true(upgrade_source.contains("var base_health_unlocked = false"), "Base-health information should remain a purchasable module")
	assert_true(upgrade_source.contains("var stats_unlocked = false"), "Stats should remain a purchasable module")
	assert_true(upgrade_source.contains("var wave_timer_unlocked = false"), "Exact wave information should remain a purchasable module")
	assert_true(upgrade_source.contains("var xp_unlocked = false"), "XP information should remain a purchasable module")
	assert_false(upgrade_source.contains("healthbar_unlocked = true\n\tbase_health_unlocked = true"), "Opening the menu must not silently grant tutorial modules")
