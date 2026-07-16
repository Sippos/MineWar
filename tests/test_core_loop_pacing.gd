@tool
extends McpTestSuite

func suite_name() -> String:
	return "core_loop_pacing"

func _source(path: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "%s must compile" % path)
	return source

func _new_enemy() -> CharacterBody2D:
	var source := FileAccess.get_file_as_string("res://enemy.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "Fresh enemy.gd source must compile")
	return script.new() as CharacterBody2D

func test_early_waves_use_a_staged_roster_and_damage_caps() -> void:
	var world_source := _source("res://scripts/systems/world_generation/world.gd")
	var enemy_source := _source("res://enemy.gd")
	assert_true(world_source.contains("if wave <= 2:"), "Wave 2 should only use the introductory roster")
	assert_true(world_source.contains("return 0 if staged_roll < 0.75 else 1"), "The introductory roster should be Rat or Spider")
	assert_true(world_source.contains("if wave <= 4:"), "Bats should arrive in a later tier")
	assert_true(world_source.contains("if wave <= 7:"), "Troggs should arrive after the early prototype loop")
	assert_true(enemy_source.contains("elif not is_boss and wave_number <= 5:"), "Early waves need a base-damage reaction window")
	assert_true(enemy_source.contains("var early_damage_cap: int = wave_number + 1"), "Early damage should scale gently and predictably")
	assert_true(world_source.contains("wave_timer = wave_interval"), "Defeating a wave should restore a full mining window")

func test_wave_two_has_time_to_react_and_is_quick_to_defend() -> void:
	var rat := _new_enemy()
	var spider := _new_enemy()
	rat.initialize(2, false, 0)
	spider.initialize(2, false, 1)
	assert_eq(int(rat.damage), 3, "Wave 2 Rat damage should be capped")
	assert_eq(int(spider.damage), 3, "Wave 2 Spider damage should be capped")
	assert_eq(int(rat.health), 28, "Wave 2 Rat health should remain readable")
	assert_eq(int(spider.health), 49, "Wave 2 Spider should be the sturdier introduction")
	var seconds_to_destroy_full_base := ceili(100.0 / float(int(rat.damage) + int(spider.damage)))
	assert_true(seconds_to_destroy_full_base >= 16, "Two unattended Wave 2 enemies should leave a meaningful reaction window")
	var strength_two_hit_damage := 20
	var attacks_to_clear := ceili(float(int(rat.health)) / float(strength_two_hit_damage)) + ceili(float(int(spider.health)) / float(strength_two_hit_damage))
	var expected_clear_seconds := float(attacks_to_clear) * 0.4
	assert_true(expected_clear_seconds <= 2.4, "A player who returns to base should clear Wave 2 quickly")
	rat.free()
	spider.free()

func test_first_upgrade_finishes_only_after_a_purchase() -> void:
	var world_source := _source("res://scripts/systems/world_generation/world.gd")
	var menu_source := _source("res://upgrade_menu.gd")
	assert_true(world_source.contains("func notify_tutorial_upgrade_purchased()"), "The tutorial should distinguish opening from buying")
	assert_true(world_source.contains("CHOOSE A QUICK STAT"), "Opening should point at an affordable stat")
	assert_true(menu_source.contains("_notify_tutorial_upgrade_purchased()"), "Successful stat purchases should advance onboarding")
	assert_true(menu_source.contains("preferred_ids.append(\"UpgradeStrength\")"), "The menu should focus affordable stat upgrades first")

func test_carry_combat_and_reward_feedback_are_explicit() -> void:
	var player_source := _source("res://player.gd")
	var hud_source := _source("res://hud.gd")
	var world_source := _source("res://scripts/systems/world_generation/world.gd")
	var coin_source := _source("res://scripts/gameplay/collectibles/drops/coin_drop.gd")
	var xp_source := _source("res://scripts/gameplay/collectibles/drops/xp_drop.gd")
	assert_true(player_source.contains("const AUTO_DEFEND_DISTANCE := 140.0"), "Idle defense should cover the full base footprint and sprite-center offsets")
	assert_true(hud_source.contains("SLOWED %d%%"), "Overloaded carrying should explain the movement penalty")
	assert_true(world_source.contains("spawn_gold_pickup_feedback"), "Gold rewards should have authored feedback")
	assert_true(world_source.contains("spawn_xp_pickup_feedback"), "XP rewards should have authored feedback")
	assert_true(coin_source.contains("spawn_gold_pickup_feedback"), "Coin pickup should trigger gold feedback")
	assert_true(xp_source.contains("spawn_xp_pickup_feedback"), "XP pickup should trigger XP feedback")
