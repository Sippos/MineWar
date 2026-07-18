extends Node

func _ready() -> void:
	_patch_player()
	_patch_upgrade_menu()
	print("MINING_TIER_PROGRESSION_APPLIED")
	get_tree().quit()

func _replace(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if not source.contains(old_text):
		push_error("Missing patch target in %s: %s" % [path, old_text.left(100)])
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _patch_player() -> void:
	var path := "res://player.gd"
	_replace(path,
		"var base_dig_time = 0.4\nvar base_jetpack_thrust = 1500.0",
		"var base_dig_time = 0.4\nvar mining_power_level := 0\nvar warned_dense_stone := false\nvar warned_ancient_stone := false\nvar base_jetpack_thrust = 1500.0")

	_replace(path,
		"\t\t\t\t\tvar current_target_dig_time = calculated_dig_time\n\t\t\t\t\tvar block_id = tile_map.get_cell_source_id(cell)\n\t\t\t\t\tif block_id == 2: current_target_dig_time = calculated_dig_time * 2.0\n\t\t\t\t\telif block_id == 3: current_target_dig_time = calculated_dig_time * 4.0",
		"\t\t\t\t\tvar block_id := tile_map.get_cell_source_id(cell)\n\t\t\t\t\tvar current_target_dig_time: float = calculated_dig_time * get_block_hardness_multiplier(block_id)")

	_replace(path,
		"\t\t\t\t\tcurrently_digging_cell = cell\n\t\t\t\t\tdig_timer = 0.0",
		"\t\t\t\t\tcurrently_digging_cell = cell\n\t\t\t\t\t_show_mining_tier_feedback(tile_map.get_cell_source_id(cell))\n\t\t\t\t\tdig_timer = 0.0")

	_replace(path,
		"func handle_digging(delta: float) -> void:",
		"func get_block_hardness_multiplier(block_id: int) -> float:\n\tvar tier := clampi(mining_power_level, 0, 3)\n\tif block_id == 2:\n\t\treturn [4.0, 2.5, 1.55, 1.0][tier]\n\tif block_id == 3:\n\t\treturn [14.0, 7.0, 3.4, 1.6][tier]\n\treturn 1.0\n\nfunc get_mining_power_level() -> int:\n\treturn mining_power_level\n\nfunc upgrade_mining_power() -> void:\n\tmining_power_level = mini(mining_power_level + 1, 3)\n\nfunc _show_mining_tier_feedback(block_id: int) -> void:\n\tvar world := get_parent()\n\tvar hud_node := world.get_node_or_null(\"HUD\") if world else null\n\tif hud_node == null or not hud_node.has_method(\"show_notice\"):\n\t\treturn\n\tif block_id == 2 and not warned_dense_stone:\n\t\twarned_dense_stone = true\n\t\thud_node.show_notice(\"DENSE STONE — breakable, but slow. Pick Power makes this layer practical.\", 4.0)\n\telif block_id == 3 and not warned_ancient_stone:\n\t\twarned_ancient_stone = true\n\t\thud_node.show_notice(\"ANCIENT WALL — your current pick barely bites. Upgrade Pick Power before committing here.\", 4.6)\n\nfunc handle_digging(delta: float) -> void:")

func _patch_upgrade_menu() -> void:
	var path := "res://upgrade_menu.gd"
	_replace(path,
		"\t_create_upgrade_tree_node(\"UpgradeIntelligence\", \"Intelligence +1\", \"Improve abilities and hero-specific summons.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Int.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_intelligence_pressed\"), upgrade_tree_stat_bar)",
		"\t_create_upgrade_tree_node(\"UpgradeIntelligence\", \"Intelligence +1\", \"Improve abilities and hero-specific summons.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Int.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_intelligence_pressed\"), upgrade_tree_stat_bar)\n\t_create_upgrade_tree_node(\"UpgradePickPower\", \"Pick Power\", \"Each rank sharply reduces dense-stone and ancient-wall resistance.\", 2, \"gems\", \"res://assets/sprites/world/terrain/bricks/Hard_Brick.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_pick_power_pressed\"), upgrade_tree_stat_bar)")

	_replace(path,
		"\t\telif id == \"UpgradeIntelligence\" and player:\n\t\t\tcost = get_upgrade_cost(player.intelligence)",
		"\t\telif id == \"UpgradeIntelligence\" and player:\n\t\t\tcost = get_upgrade_cost(player.intelligence)\n\t\telif id == \"UpgradePickPower\" and player:\n\t\t\tcost = get_pick_power_cost()")

	_replace(path,
		"\t\tvar currency := str(upgrade_tree_currency.get(id, \"gold\"))",
		"\t\tif id == \"UpgradePickPower\" and player:\n\t\t\tvar pick_title := button.get_node_or_null(\"Title\") as Label\n\t\t\tif pick_title:\n\t\t\t\tvar pick_level := int(player.get(\"mining_power_level\"))\n\t\t\t\tpick_title.text = \"Pick MAX\" if pick_level >= 3 else \"Pick Lv %d\" % pick_level\n\t\tvar currency := str(upgrade_tree_currency.get(id, \"gold\"))")

	_replace(path,
		"\t\t\"UpgradeMinimap\": return minimap_upgraded\n\treturn false",
		"\t\t\"UpgradeMinimap\": return minimap_upgraded\n\t\t\"UpgradePickPower\": return player != null and int(player.get(\"mining_power_level\")) >= 3\n\treturn false")

	_replace(path,
		"\t\tif available_gems >= get_upgrade_cost(int(player.intelligence)):\n\t\t\tpreferred_ids.append(\"UpgradeIntelligence\")",
		"\t\tif available_gems >= get_upgrade_cost(int(player.intelligence)):\n\t\t\tpreferred_ids.append(\"UpgradeIntelligence\")\n\t\tif int(player.get(\"mining_power_level\")) < 3 and available_gems >= get_pick_power_cost():\n\t\t\tpreferred_ids.append(\"UpgradePickPower\")")

	_replace(path,
		"func _get_stat_upgrade_color(stat_name: String) -> Color:\n\tmatch stat_name:",
		"func get_pick_power_cost() -> int:\n\tif player == null:\n\t\treturn 999999\n\treturn 2 + int(player.get(\"mining_power_level\")) * 3\n\nfunc _get_stat_upgrade_color(stat_name: String) -> Color:\n\tmatch stat_name:")

	_replace(path,
		"\t\t\"Intelligence\":\n\t\t\treturn Color(0.25, 0.65, 1.0, 1.0)\n\treturn Color(1.0, 0.9, 0.25, 1.0)",
		"\t\t\"Intelligence\":\n\t\t\treturn Color(0.25, 0.65, 1.0, 1.0)\n\t\t\"Pick Power\":\n\t\t\treturn Color(1.0, 0.66, 0.22, 1.0)\n\treturn Color(1.0, 0.9, 0.25, 1.0)")

	_replace(path,
		"func _on_upgrade_intelligence_pressed():\n\tvar cost = get_upgrade_cost(player.intelligence)\n\tif hud.total_gems >= cost:\n\t\thud.add_gems(-cost)\n\t\tplayer.upgrade_intelligence()\n\t\thud.update_stats(player.strength, player.agility, player.intelligence)\n\t\t_play_stat_upgrade_effect(\"Intelligence\", $Panel/UpgradeIntelligence)\n\t\tupdate_button_texts()\n\t\t_notify_tutorial_upgrade_purchased()",
		"func _on_upgrade_intelligence_pressed():\n\tvar cost = get_upgrade_cost(player.intelligence)\n\tif hud.total_gems >= cost:\n\t\thud.add_gems(-cost)\n\t\tplayer.upgrade_intelligence()\n\t\thud.update_stats(player.strength, player.agility, player.intelligence)\n\t\t_play_stat_upgrade_effect(\"Intelligence\", $Panel/UpgradeIntelligence)\n\t\tupdate_button_texts()\n\t\t_notify_tutorial_upgrade_purchased()\n\nfunc _on_upgrade_pick_power_pressed() -> void:\n\tif player == null or int(player.get(\"mining_power_level\")) >= 3:\n\t\treturn\n\tvar cost := get_pick_power_cost()\n\tif hud.total_gems < cost:\n\t\treturn\n\thud.add_gems(-cost)\n\tplayer.upgrade_mining_power()\n\t_play_stat_upgrade_effect(\"Pick Power\", upgrade_tree_buttons.get(\"UpgradePickPower\") as Control)\n\t_notify_tutorial_upgrade_purchased()")
