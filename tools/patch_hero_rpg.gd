extends Node

var failed: bool = false

func _ready() -> void:
	_patch_player()
	_patch_abilities()
	_patch_balance_controller()
	_patch_upgrade_copy()
	if failed:
		push_error("HERO_RPG_PATCH_FAILED")
		get_tree().quit(1)
		return
	print("HERO_RPG_PATCH_APPLIED")
	get_tree().quit()

func _replace_checked(text: String, old_text: String, new_text: String, label: String) -> String:
	if not text.contains(old_text):
		push_error("Missing patch target: " + label)
		failed = true
		return text
	return text.replace(old_text, new_text)

func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		failed = true
		return
	file.store_string(text)
	file.close()

func _patch_player() -> void:
	var path: String = "res://player.gd"
	var text: String = FileAccess.get_file_as_string(path)
	text = _replace_checked(text,
		"func upgrade_strength() -> void:\n\tstrength += 1\n\nfunc upgrade_agility() -> void:\n\tagility += 1\n\nfunc upgrade_intelligence() -> void:\n\tintelligence += 1",
		"func _rpg_controller() -> Node:\n\treturn get_node_or_null(\"HeroRPGController\")\n\nfunc upgrade_strength() -> void:\n\tvar rpg: Node = _rpg_controller()\n\tif rpg != null and rpg.has_method(\"register_stat_bonus\"):\n\t\trpg.call(\"register_stat_bonus\", \"strength\", 1)\n\telse:\n\t\tstrength += 1\n\nfunc upgrade_agility() -> void:\n\tvar rpg: Node = _rpg_controller()\n\tif rpg != null and rpg.has_method(\"register_stat_bonus\"):\n\t\trpg.call(\"register_stat_bonus\", \"agility\", 1)\n\telse:\n\t\tagility += 1\n\nfunc upgrade_intelligence() -> void:\n\tvar rpg: Node = _rpg_controller()\n\tif rpg != null and rpg.has_method(\"register_stat_bonus\"):\n\t\trpg.call(\"register_stat_bonus\", \"intelligence\", 1)\n\telse:\n\t\tintelligence += 1",
		"player upgrade routing")
	text = _replace_checked(text,
		"func take_damage(amount: int) -> void:\n\tif is_dead or invulnerability_timer > 0.0:\n\t\treturn\n\tinvulnerability_timer = 1.0\n\thealth -= amount",
		"func take_damage(amount: int) -> void:\n\tif is_dead or invulnerability_timer > 0.0:\n\t\treturn\n\tvar applied_amount: int = amount\n\tvar rpg: Node = _rpg_controller()\n\tif rpg != null and rpg.has_method(\"modify_incoming_damage\"):\n\t\tapplied_amount = int(rpg.call(\"modify_incoming_damage\", amount))\n\tif applied_amount <= 0:\n\t\treturn\n\tinvulnerability_timer = 1.0\n\thealth -= applied_amount",
		"player armor damage")
	text = _replace_checked(text,
		"\tvar penalty = get_weight_penalty()\n\tvar current_speed = (base_speed + (agility - 1) * 20.0) * (1.0 - penalty)",
		"\tvar penalty: float = get_weight_penalty()\n\tvar rpg_movement: Node = _rpg_controller()\n\tvar current_speed: float = base_speed + float(agility - 1) * 3.0\n\tif rpg_movement != null and rpg_movement.has_method(\"get_move_speed\"):\n\t\tcurrent_speed = float(rpg_movement.call(\"get_move_speed\"))\n\tcurrent_speed *= 1.0 - penalty",
		"player movement derivation")
	text = _replace_checked(text,
		"\t\tattack_timer += delta\n\t\tvar attack_interval = base_dig_time * pow(0.9, agility - 1)\n\t\tif attack_timer >= attack_interval:\n\t\t\tvar damage = 10 * strength\n\t\t\tif enemy_hit.has_method(\"take_damage\"):\n\t\t\t\tenemy_hit.take_damage(damage)",
		"\t\tattack_timer += delta\n\t\tvar rpg_combat: Node = _rpg_controller()\n\t\tvar attack_interval: float = base_dig_time * pow(0.965, agility - 1)\n\t\tif rpg_combat != null and rpg_combat.has_method(\"get_attack_interval\"):\n\t\t\tattack_interval = float(rpg_combat.call(\"get_attack_interval\"))\n\t\tif attack_timer >= attack_interval:\n\t\t\tvar damage: int = 10 * strength\n\t\t\tif rpg_combat != null and rpg_combat.has_method(\"get_basic_attack_damage\"):\n\t\t\t\tdamage = int(rpg_combat.call(\"get_basic_attack_damage\"))\n\t\t\tif enemy_hit.has_method(\"take_damage\"):\n\t\t\t\tenemy_hit.take_damage(damage)",
		"player attack derivation")
	text = _replace_checked(text,
		"\t\t\t\t\tvar calculated_dig_time = base_dig_time * pow(0.9, agility - 1)\n\t\t\t\t\tcalculated_dig_time *= _get_shaman_dig_time_multiplier()",
		"\t\t\t\t\tvar calculated_dig_time: float = base_dig_time\n\t\t\t\t\tvar rpg_mining: Node = _rpg_controller()\n\t\t\t\t\tif rpg_mining != null and rpg_mining.has_method(\"get_dig_time_multiplier\"):\n\t\t\t\t\t\tcalculated_dig_time *= float(rpg_mining.call(\"get_dig_time_multiplier\"))\n\t\t\t\t\telse:\n\t\t\t\t\t\tcalculated_dig_time *= pow(0.975, agility - 1)\n\t\t\t\t\tcalculated_dig_time *= _get_shaman_dig_time_multiplier()",
		"player mining derivation")
	text = _replace_checked(text,
		"\telif upgrade_type == \"health\":\n\t\tmax_health += 10\n\t\thealth += 10\n\telif upgrade_type == \"damage\":\n\t\tstrength += 1",
		"\telif upgrade_type == \"health\":\n\t\tvar rpg_health: Node = _rpg_controller()\n\t\tif rpg_health != null and rpg_health.has_method(\"register_health_bonus\"):\n\t\t\trpg_health.call(\"register_health_bonus\", 10)\n\t\telse:\n\t\t\tmax_health += 10\n\t\t\thealth += 10\n\telif upgrade_type == \"damage\":\n\t\tupgrade_strength()",
		"level-up stat rewards")
	text = _replace_checked(text,
		"func perform_stomp() -> void:\n\tstomp_cooldown_timer = max(1.0, 5.0 - stomp_level * 0.5)\n\tvar radius = 100.0 + stomp_level * 20.0\n\tvar stomp_damage = 20 * stomp_level * strength",
		"func perform_stomp() -> void:\n\tvar rpg_stomp: Node = _rpg_controller()\n\tvar stomp_base_cooldown: float = max(1.0, 5.0 - stomp_level * 0.5)\n\tstomp_cooldown_timer = float(rpg_stomp.call(\"adjust_cooldown\", stomp_base_cooldown)) if rpg_stomp != null and rpg_stomp.has_method(\"adjust_cooldown\") else stomp_base_cooldown\n\tvar radius = 100.0 + stomp_level * 20.0\n\tvar base_stomp_damage: int = 12 + stomp_level * 18 + strength * 5\n\tvar stomp_damage: int = int(rpg_stomp.call(\"scale_physical_ability_damage\", base_stomp_damage)) if rpg_stomp != null and rpg_stomp.has_method(\"scale_physical_ability_damage\") else base_stomp_damage",
		"stomp RPG scaling")
	_write(path, text)

func _patch_abilities() -> void:
	var path: String = "res://hero_abilities.gd"
	var text: String = FileAccess.get_file_as_string(path)
	text = _replace_checked(text,
		"func _action(suffix: String) -> String:\n\treturn \"p%d_%s\" % [_player_id(), suffix]",
		"func _action(suffix: String) -> String:\n\treturn \"p%d_%s\" % [_player_id(), suffix]\n\nfunc _rpg_controller() -> Node:\n\treturn player.get_node_or_null(\"HeroRPGController\")\n\nfunc _rpg_cooldown(value: float) -> float:\n\tvar rpg: Node = _rpg_controller()\n\treturn float(rpg.call(\"adjust_cooldown\", value)) if rpg != null and rpg.has_method(\"adjust_cooldown\") else value\n\nfunc _rpg_duration(value: float) -> float:\n\tvar rpg: Node = _rpg_controller()\n\treturn float(rpg.call(\"adjust_duration\", value)) if rpg != null and rpg.has_method(\"adjust_duration\") else value\n\nfunc _rpg_spell_damage(value: int) -> int:\n\tvar rpg: Node = _rpg_controller()\n\treturn int(rpg.call(\"scale_spell_damage\", value)) if rpg != null and rpg.has_method(\"scale_spell_damage\") else value\n\nfunc _rpg_summon_damage(value: int) -> int:\n\tvar rpg: Node = _rpg_controller()\n\treturn int(rpg.call(\"scale_summon_damage\", value)) if rpg != null and rpg.has_method(\"scale_summon_damage\") else value\n\nfunc _rpg_physical_damage(value: int) -> int:\n\tvar rpg: Node = _rpg_controller()\n\treturn int(rpg.call(\"scale_physical_ability_damage\", value)) if rpg != null and rpg.has_method(\"scale_physical_ability_damage\") else value",
		"ability RPG helpers")
	text = _replace_checked(text,
		"\treturn max(4.5, 9.0 - hammer_level * 0.75 - (int(player.get(\"intelligence\")) - 1) * 0.08)",
		"\treturn _rpg_cooldown(max(4.5, 9.0 - hammer_level * 0.75))",
		"hammer cooldown")
	text = _replace_checked(text,
		"\tvar damage_value := 70 + hammer_level * 55 + int(player.get(\"strength\")) * 16",
		"\tvar damage_value: int = _rpg_physical_damage(70 + hammer_level * 55 + int(player.get(\"strength\")) * 16)",
		"hammer damage")
	text = _replace_checked(text,
		"\tvar bonus_damage := 25 + bash_level * 25 + int(player.get(\"strength\")) * 8",
		"\tvar bonus_damage: int = _rpg_physical_damage(25 + bash_level * 25 + int(player.get(\"strength\")) * 8)",
		"bash damage")
	text = _replace_checked(text,
		"\treturn max(3.0, cooldown)",
		"\treturn _rpg_cooldown(max(3.0, cooldown))",
		"totem cooldown")
	text = _replace_checked(text,
		"\tvar lifetime_value := 18.0 + totem_level * 5.0 + wisdom_level * 3.0",
		"\tvar lifetime_value: float = _rpg_duration(18.0 + totem_level * 5.0 + wisdom_level * 3.0)",
		"totem duration")
	text = _replace_checked(text,
		"\tvar damage_value := 35 + chain_level * 38 + int(player.get(\"intelligence\")) * 12",
		"\tvar damage_value: int = _rpg_spell_damage(35 + chain_level * 38 + int(player.get(\"intelligence\")) * 12)",
		"chain damage")
	text = _replace_checked(text,
		"\treturn max(2.5, cooldown)",
		"\treturn _rpg_cooldown(max(2.5, cooldown))",
		"chain cooldown")
	text = _replace_checked(text,
		"\tascendance_duration = 12.0\n\tascendance_cooldown = 65.0",
		"\tascendance_duration = _rpg_duration(12.0)\n\tascendance_cooldown = _rpg_cooldown(65.0)",
		"ascendance timing")
	text = _replace_checked(text,
		"\tmole_duration = 6.0 + float(mole_level) * 2.0\n\tmole_cooldown = max(8.0, 16.0 - float(mole_level))",
		"\tmole_duration = _rpg_duration(6.0 + float(mole_level) * 2.0)\n\tmole_cooldown = _rpg_cooldown(max(8.0, 16.0 - float(mole_level)))",
		"mole timing")
	text = _replace_checked(text,
		"\t\ttunnel_cooldown = max(5.0, 10.0 - tunnel_level)",
		"\t\ttunnel_cooldown = _rpg_cooldown(max(5.0, 10.0 - tunnel_level))",
		"tunnel placement cooldown")
	text = _replace_checked(text,
		"\ttunnel_cooldown = max(3.5, 7.0 - tunnel_level * 0.75)",
		"\ttunnel_cooldown = _rpg_cooldown(max(3.5, 7.0 - tunnel_level * 0.75))",
		"tunnel travel cooldown")
	text = _replace_checked(text,
		"\tworldroot_cooldown = 45.0",
		"\tworldroot_cooldown = _rpg_cooldown(45.0)",
		"worldroot cooldown")
	text = _replace_checked(text,
		"\tundead_summon_cooldown = max(5.0, 11.0 - float(int(player.get(\"intelligence\")) - 1) * 0.25)",
		"\tundead_summon_cooldown = _rpg_cooldown(max(5.0, 11.0 - float(undead_summon_level) * 0.65))",
		"raise dead cooldown")
	text = _replace_checked(text,
		"\tminion.set(\"max_lifetime\", 36.0 + float(intelligence - 1) * 2.0 + grave_might_level * 8.0)\n\tminion.set(\"attack_damage\", 10 + intelligence * 4 + grave_might_level * 7)",
		"\tminion.set(\"max_lifetime\", _rpg_duration(36.0 + float(intelligence - 1) * 2.0 + grave_might_level * 8.0))\n\tminion.set(\"attack_damage\", _rpg_summon_damage(10 + intelligence * 4 + grave_might_level * 7))",
		"undead summon scaling")
	text = _replace_checked(text,
		"\tdeath_march_cooldown = 60.0",
		"\tdeath_march_cooldown = _rpg_cooldown(60.0)",
		"death march cooldown")
	text = _replace_checked(text,
		"\treturn max(2.4, 5.8 - brood_level * 0.75 - carapace_level * 0.15)",
		"\treturn _rpg_cooldown(max(2.4, 5.8 - brood_level * 0.75 - carapace_level * 0.15))",
		"brood cooldown")
	text = _replace_checked(text,
		"\tspider.set(\"max_lifetime\", 48.0 + brood_level * 14.0 + carapace_level * 6.0)",
		"\tspider.set(\"max_lifetime\", _rpg_duration(48.0 + brood_level * 14.0 + carapace_level * 6.0))",
		"spider duration")
	text = _replace_checked(text,
		"\tspider.set(\"attack_damage\", 5 + intelligence * 3 + brood_level * 4)",
		"\tspider.set(\"attack_damage\", _rpg_summon_damage(5 + intelligence * 3 + brood_level * 4))",
		"spider damage")
	text = _replace_checked(text,
		"\tweb_cooldown = max(5.5, 10.5 - web_level * 1.1 - carapace_level * 0.2)",
		"\tweb_cooldown = _rpg_cooldown(max(5.5, 10.5 - web_level * 1.1 - carapace_level * 0.2))",
		"web cooldown")
	text = _replace_checked(text,
		"\tvar damage_value := base_damage + int(player.get(\"intelligence\")) * 7",
		"\tvar damage_value: int = _rpg_spell_damage(base_damage + int(player.get(\"intelligence\")) * 7)",
		"web damage")
	text = _replace_checked(text,
		"\tbroodmother_duration = 14.0\n\tbroodmother_cooldown = 70.0",
		"\tbroodmother_duration = _rpg_duration(14.0)\n\tbroodmother_cooldown = _rpg_cooldown(70.0)",
		"broodmother timing")
	_write(path, text)

func _patch_balance_controller() -> void:
	var path: String = "res://hero_balance_controller.gd"
	var text: String = FileAccess.get_file_as_string(path)
	text = _replace_checked(text,
		"func _action(suffix: String) -> String:\n\treturn \"p%d_%s\" % [int(player.get(\"player_id\")), suffix]",
		"func _action(suffix: String) -> String:\n\treturn \"p%d_%s\" % [int(player.get(\"player_id\")), suffix]\n\nfunc _rpg_controller() -> Node:\n\treturn player.get_node_or_null(\"HeroRPGController\")\n\nfunc _rpg_spell_damage(value: int) -> int:\n\tvar rpg: Node = _rpg_controller()\n\treturn int(rpg.call(\"scale_spell_damage\", value)) if rpg != null and rpg.has_method(\"scale_spell_damage\") else value\n\nfunc _rpg_summon_damage(value: int) -> int:\n\tvar rpg: Node = _rpg_controller()\n\treturn int(rpg.call(\"scale_summon_damage\", value)) if rpg != null and rpg.has_method(\"scale_summon_damage\") else value\n\nfunc _rpg_cooldown(value: float) -> float:\n\tvar rpg: Node = _rpg_controller()\n\treturn float(rpg.call(\"adjust_cooldown\", value)) if rpg != null and rpg.has_method(\"adjust_cooldown\") else value\n\nfunc _rpg_duration(value: float) -> float:\n\tvar rpg: Node = _rpg_controller()\n\treturn float(rpg.call(\"adjust_duration\", value)) if rpg != null and rpg.has_method(\"adjust_duration\") else value",
		"balance RPG helpers")
	text = _replace_checked(text,
		"\tvar agility := int(player.get(\"agility\"))\n\tvar brood_rank := int(hero_abilities.get(\"brood_level\")) if hero_abilities else 1\n\tvar target_time := float(player.get(\"base_dig_time\")) * pow(0.9, agility - 1) * 1.15",
		"\tvar brood_rank := int(hero_abilities.get(\"brood_level\")) if hero_abilities else 1\n\tvar target_time: float = float(player.get(\"base_dig_time\")) * 1.15\n\tvar rpg: Node = _rpg_controller()\n\tif rpg != null and rpg.has_method(\"get_dig_time_multiplier\"):\n\t\ttarget_time *= float(rpg.call(\"get_dig_time_multiplier\"))",
		"nerubian mining scaling")
	text = _replace_checked(text,
		"\tvar damage := 10 + intelligence * 5 + web_rank * 6",
		"\tvar damage: int = _rpg_spell_damage(10 + intelligence * 5 + web_rank * 6)",
		"venom spell scaling")
	text = _replace_checked(text,
		"\tvar damage := 8 + mole_rank * 6 + int(player.get(\"intelligence\")) * 4",
		"\tvar damage: int = _rpg_spell_damage(8 + mole_rank * 6 + int(player.get(\"intelligence\")) * 4)",
		"verdant burrow scaling")
	text = _replace_checked(text,
		"\tvar damage := 4 + mole_rank * 4 + int(player.get(\"intelligence\")) * 2",
		"\tvar damage: int = _rpg_spell_damage(4 + mole_rank * 4 + int(player.get(\"intelligence\")) * 2)",
		"burrow pulse scaling")
	text = _replace_checked(text,
		"\tgrave_might_duration = 5.0 + level\n\tgrave_might_cooldown = max(8.0, 14.0 - level * 1.5)",
		"\tgrave_might_duration = _rpg_duration(5.0 + level)\n\tgrave_might_cooldown = _rpg_cooldown(max(8.0, 14.0 - level * 1.5))",
		"grave might timing")
	text = _replace_checked(text,
		"\t\t\t\tif enemy.has_method(\"take_damage\"):\n\t\t\t\t\tenemy.call(\"take_damage\", 18 + level * 14 + int(player.get(\"intelligence\")) * 4)",
		"\t\t\t\tif enemy.has_method(\"take_damage\"):\n\t\t\t\t\tenemy.call(\"take_damage\", _rpg_summon_damage(18 + level * 14 + int(player.get(\"intelligence\")) * 4))",
		"grave might damage")
	_write(path, text)

func _patch_upgrade_copy() -> void:
	var economy_path: String = "res://economy_clarity.gd"
	var economy: String = FileAccess.get_file_as_string(economy_path)
	economy = _replace_checked(economy,
		"\t_add_action_button(hero_column, \"strength\", \"Strength +1\", \"More attack and stomp damage; +1 free gem carry every 3 STR\")\n\t_add_action_button(hero_column, \"agility\", \"Agility +1\", \"Faster movement, attacks, and digging\")\n\t_add_action_button(hero_column, \"intelligence\", \"Intelligence +1\", \"Stronger and faster hero abilities; faster brood recovery\")",
		"\t_add_action_button(hero_column, \"strength\", \"Strength +1\", \"Basic damage, +6 health, regeneration, carrying, and primary-attribute damage\")\n\t_add_action_button(hero_column, \"agility\", \"Agility +1\", \"+3.5% attack speed, movement, armor, and a smaller mining bonus\")\n\t_add_action_button(hero_column, \"intelligence\", \"Intelligence +1\", \"Spell and summon power, shorter cooldowns, and longer effects\")",
		"economy RPG descriptions")
	_write(economy_path, economy)
	var menu_path: String = "res://upgrade_menu.gd"
	var menu: String = FileAccess.get_file_as_string(menu_path)
	menu = menu.replace("\"Faster movement, attacks and digging.\"", "\"Attack speed, movement, armor, and a smaller mining bonus.\"")
	_write(menu_path, menu)
