extends Node

func _patch(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if not source.contains(old_text):
		push_error("Missing patch target in %s: %s" % [path, old_text.left(100)])
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _ready() -> void:
	_patch(
		"res://upgrade_menu.gd",
		"func get_upgrade_cost(stat_level: int) -> int:\n\treturn (stat_level * 2) - 1",
		"func get_upgrade_cost(stat_level: int) -> int:\n\t# MineWars rewards frequent, readable build choices. Competitive modes keep\n\t# the escalating economy so this single-player tuning does not affect LineWars.\n\treturn (stat_level * 2) - 1 if _is_vs_mode() else 1"
	)
	_patch(
		"res://upgrade_menu.gd",
		"\t_create_upgrade_tree_node(\"UpgradeStrength\", \"Strength +1\", \"More damage and free carrying thresholds.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Strenght.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_strength_pressed\"), upgrade_tree_stat_bar)\n\t_create_upgrade_tree_node(\"UpgradeAgility\", \"Agility +1\", \"Attack speed, movement, armor, and a smaller mining bonus.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Agility.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_agility_pressed\"), upgrade_tree_stat_bar)\n\t_create_upgrade_tree_node(\"UpgradeIntelligence\", \"Intelligence +1\", \"Improve abilities and hero-specific summons.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Int.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_intelligence_pressed\"), upgrade_tree_stat_bar)",
		"\t_create_upgrade_tree_node(\"UpgradeStrength\", \"STR +1\", \"Always 1 gem in MineWars. More damage, hard-rock force, and free carrying thresholds.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Strenght.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_strength_pressed\"), upgrade_tree_stat_bar)\n\t_create_upgrade_tree_node(\"UpgradeAgility\", \"AGI +1\", \"Always 1 gem in MineWars. Faster attacks, movement, and mining cadence.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Agility.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_agility_pressed\"), upgrade_tree_stat_bar)\n\t_create_upgrade_tree_node(\"UpgradeIntelligence\", \"INT +1\", \"Always 1 gem in MineWars. Stronger abilities, summons, and magical mining utility.\", 1, \"gems\", \"res://assets/sprites/ui/common/stats/Int.png\", Vector2.ZERO, Callable(self, \"_on_upgrade_intelligence_pressed\"), upgrade_tree_stat_bar)"
	)
	_patch(
		"res://upgrade_menu.gd",
		"\t\tif id == \"UpgradePickPower\" and player:\n\t\t\tvar pick_title := button.get_node_or_null(\"Title\") as Label\n\t\t\tif pick_title:\n\t\t\t\tvar pick_level := int(player.get(\"mining_power_level\"))\n\t\t\t\tpick_title.text = \"Pick MAX\" if pick_level >= 3 else \"Pick Lv %d\" % pick_level\n\t\tvar currency := str(upgrade_tree_currency.get(id, \"gold\"))",
		"\t\tvar title_label := button.get_node_or_null(\"Title\") as Label\n\t\tif title_label and player:\n\t\t\tmatch id:\n\t\t\t\t\"UpgradeStrength\":\n\t\t\t\t\ttitle_label.text = \"STR %d → %d\" % [int(player.strength), int(player.strength) + 1]\n\t\t\t\t\"UpgradeAgility\":\n\t\t\t\t\ttitle_label.text = \"AGI %d → %d\" % [int(player.agility), int(player.agility) + 1]\n\t\t\t\t\"UpgradeIntelligence\":\n\t\t\t\t\ttitle_label.text = \"INT %d → %d\" % [int(player.intelligence), int(player.intelligence) + 1]\n\t\t\t\t\"UpgradePickPower\":\n\t\t\t\t\tvar pick_level := int(player.get(\"mining_power_level\"))\n\t\t\t\t\ttitle_label.text = \"Pick MAX\" if pick_level >= 3 else \"Pick Lv %d\" % pick_level\n\t\tvar currency := str(upgrade_tree_currency.get(id, \"gold\"))"
	)
	_patch(
		"res://base.gd",
		"func _get_minimum_stat_upgrade_cost(player: Node) -> int:\n\tif player == null:\n\t\treturn 999999\n\tvar strength_cost: int = max(int(player.get(\"strength\")), 1) * 2 - 1\n\tvar agility_cost: int = max(int(player.get(\"agility\")), 1) * 2 - 1\n\tvar intelligence_cost: int = max(int(player.get(\"intelligence\")), 1) * 2 - 1\n\treturn min(strength_cost, min(agility_cost, intelligence_cost))",
		"func _get_minimum_stat_upgrade_cost(player: Node) -> int:\n\tif player == null:\n\t\treturn 999999\n\t# MineWars stat purchases remain affordable whenever the player has one gem.\n\treturn 1"
	)
	print("FLAT_MINEWARS_STAT_COSTS_APPLIED")
	get_tree().quit()
