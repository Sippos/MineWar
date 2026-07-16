@tool
extends McpTestSuite

func suite_name() -> String:
	return "satchel_reward"

func test_miners_satchel_adds_one_nonstacking_free_carry_slot() -> void:
	var player_script := GDScript.new()
	player_script.source_code = FileAccess.get_file_as_string("res://player.gd")
	assert_eq(player_script.reload(), OK, "Fresh player.gd source must compile")
	var player: CharacterBody2D = player_script.new() as CharacterBody2D
	track(player)
	assert_eq(player.get_free_carry_allowance(), 1)
	assert_true(player.apply_cave_reward("miners_satchel"))
	assert_eq(player.get_free_carry_allowance(), 2)
	assert_eq(player.cave_reward_carry_bonus, 1)
	assert_false(player.apply_cave_reward("miners_satchel"), "The same cave reward must not stack twice")
	assert_eq(player.get_free_carry_allowance(), 2)
	assert_false(player.apply_cave_reward("unknown_reward"))
	assert_eq(player.cave_reward_ids, ["miners_satchel"])

func test_satchel_stays_visible_in_the_hud_after_pickup() -> void:
	var hud_script := GDScript.new()
	hud_script.source_code = FileAccess.get_file_as_string("res://hud.gd")
	assert_eq(hud_script.reload(), OK, "Fresh hud.gd source must compile")
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	track(hud)
	assert_true(hud.add_cave_reward("miners_satchel"))
	assert_false(hud.add_cave_reward("miners_satchel"), "The HUD must not duplicate the same permanent reward")
	assert_true(hud.cave_reward_container.visible)
	assert_eq(hud.cave_reward_slots.size(), 1)
	var slot: PanelContainer = hud.cave_reward_slots["miners_satchel"] as PanelContainer
	assert_false(slot == null)
	var labels: Array[Node] = slot.find_children("*", "Label", true, false)
	var combined_text := ""
	for node in labels:
		var reward_label := node as Label
		if reward_label:
			combined_text += reward_label.text + " "
	assert_true(combined_text.contains("MINER'S SATCHEL"))
	assert_true(combined_text.contains("+1 FREE CARRY"))
