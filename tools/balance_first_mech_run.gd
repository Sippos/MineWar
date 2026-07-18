extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch("res://scripts/systems/world_generation/siege_mode_controller.gd", "const MINEWARS_BOSS_HEALTH := 620", "const MINEWARS_BOSS_HEALTH := 540")
	_patch("res://scripts/systems/world_generation/siege_mode_controller.gd", "const MINEWARS_BOSS_DAMAGE := 12", "const MINEWARS_BOSS_DAMAGE := 9")
	_patch("res://scripts/systems/world_generation/siege_mode_controller.gd", "const MINEWARS_BOSS_SPEED := 48.0", "const MINEWARS_BOSS_SPEED := 46.0")

	_patch(
		"res://enemy_combat_behavior.gd",
		"_begin_windup(\"boss_charge\", target, 0.68 if boss_phase == 1 else 0.48, 54.0, Color(1.0, 0.16, 0.08, 0.96), true)",
		"_begin_windup(\"boss_charge\", target, 0.82 if boss_phase == 1 else (0.62 if boss_phase == 2 else 0.50), 54.0, Color(1.0, 0.16, 0.08, 0.96), true)"
	)
	_patch(
		"res://enemy_combat_behavior.gd",
		"_begin_windup(\"boss_mortar\", target, 0.62 if boss_phase == 1 else 0.48, 70.0, Color(1.0, 0.58, 0.08, 0.96))",
		"_begin_windup(\"boss_mortar\", target, 0.76 if boss_phase == 1 else (0.64 if boss_phase == 2 else 0.54), 62.0, Color(1.0, 0.58, 0.08, 0.96))"
	)
	_patch(
		"res://enemy_combat_behavior.gd",
		"_begin_windup(\"boss_exhaust\", target, 0.44, 94.0, Color(0.36, 1.0, 0.24, 0.9))",
		"_begin_windup(\"boss_exhaust\", target, 0.56, 86.0, Color(0.36, 1.0, 0.24, 0.9))"
	)
	_patch("res://enemy_combat_behavior.gd", "exhaust_drop_timer = 0.16", "exhaust_drop_timer = 0.22")
	_patch("res://enemy_combat_behavior.gd", "_spawn_poison_pool(enemy.global_position, 42.0, 2.4, 1)", "_spawn_poison_pool(enemy.global_position, 38.0, 1.8, 1)")
	_patch("res://enemy_combat_behavior.gd", "exhaust_drop_timer = 0.2", "exhaust_drop_timer = 0.28")
	_patch("res://enemy_combat_behavior.gd", "randf_range(24.0, 72.0)", "randf_range(36.0, 82.0)")
	_patch(
		"res://enemy_combat_behavior.gd",
		"_spawn_poison_pool(enemy.global_position + offset, 48.0, 3.1, maxi(1, int(ceil(float(enemy.get(\"damage\")) * 0.12))))",
		"_spawn_poison_pool(enemy.global_position + offset, 42.0, 2.3, 1)"
	)
	_patch(
		"res://enemy_combat_behavior.gd",
		"var offsets := [Vector2.ZERO, Vector2(62, 26), Vector2(-58, -22)]",
		"var offsets := [Vector2.ZERO, Vector2(86, 34), Vector2(-82, -36)]"
	)
	_patch("res://enemy_combat_behavior.gd", "offsets.append(Vector2(18, -68))", "offsets.append(Vector2(20, -96))")
	_patch(
		"res://enemy_combat_behavior.gd",
		"marker.configure(world, center + offsets[index], maxi(2, int(ceil(float(hit_damage) * 0.55))), 58.0, 0.72 + float(index) * 0.1, boss_phase >= 2 and index == offsets.size() - 1)",
		"marker.configure(world, center + offsets[index], maxi(2, int(ceil(float(hit_damage) * 0.55))), 50.0, 0.90 + float(index) * 0.16, boss_phase >= 2 and index == offsets.size() - 1)"
	)
	_patch(
		"res://enemy_combat_behavior.gd",
		"\t\t1: return 1.35\n\t\t2: return 0.98\n\t\t_: return 0.72",
		"\t\t1: return 1.55\n\t\t2: return 1.18\n\t\t_: return 0.92"
	)

	_patch("res://enemy_projectile.gd", "var poison_radius := 58.0", "var poison_radius := 48.0")
	_patch("res://enemy_projectile.gd", "var poison_duration := 4.0", "var poison_duration := 2.8")
	_patch(
		"res://enemy_mortar_marker.gd",
		"pool.configure(world, global_position, blast_radius * 0.82, 3.3, maxi(1, int(ceil(float(damage) * 0.18))))",
		"pool.configure(world, global_position, blast_radius * 0.72, 2.4, 1)"
	)

	_patch("res://goblin_pilot.gd", "var health := 85", "var health := 65")
	_patch("res://goblin_pilot.gd", "var max_health := 85", "var max_health := 65")
	_patch("res://goblin_pilot.gd", "\thealth = 85\n\tmax_health = health", "\thealth = 65\n\tmax_health = health")
	_patch("res://goblin_pilot.gd", "attack_timer = 1.35", "attack_timer = 1.55")

	_patch(
		"res://hero_balance_controller.gd",
		"\t\"Dwarf\": {\"health\": 40, \"speed\": 190.0, \"dig_time\": 0.36},",
		"\t\"Dwarf\": {\"health\": 40, \"speed\": 190.0, \"dig_time\": 0.36},\n\t\"Mech\": {\"health\": 52, \"speed\": 176.0, \"dig_time\": 0.34},"
	)
	_patch(
		"res://hero_balance_controller.gd",
		"\t\"Dwarf\": 1.0,",
		"\t\"Dwarf\": 1.0,\n\t\"Mech\": 1.08,"
	)
	_patch(
		"res://hero_rpg_controller.gd",
		"\t\"Shaman\": {",
		"\t\"Mech\": {\n\t\t\"primary\": \"strength\",\n\t\t\"base_stats\": {\"strength\": 5, \"agility\": 1, \"intelligence\": 1},\n\t\t\"growth\": {\"strength\": 0.90, \"agility\": 0.20, \"intelligence\": 0.15},\n\t\t\"base_health\": 52,\n\t\t\"base_attack_damage\": 7.0,\n\t\t\"base_attack_interval\": 0.86,\n\t\t\"base_armor\": 2.00,\n\t\t\"base_regen\": 0.16\n\t},\n\t\"Shaman\": {"
	)

	var old_rewards := "const MINEWARS_VICTORY_REWARDS := {\n\t1: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Shaman\",\n\t\t\"base\": \"shaman_base\",\n\t\t\"title\": \"THE SHAMAN ANSWERS\",\n\t\t\"description\": \"Shaman and the Shaman Lodge have joined the stronghold.\"\n\t},\n\t2: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Druid\",\n\t\t\"base\": \"druid_base\",\n\t\t\"title\": \"ROOTS BREAK THE STONE\",\n\t\t\"description\": \"Druid and the Druid Grove have awakened.\"\n\t},\n\t3: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Nerubian\",\n\t\t\"base\": \"nerubian_base\",\n\t\t\"title\": \"THE BROOD EMERGES\",\n\t\t\"description\": \"Nerubian and the Nerubian Nest have joined the war.\"\n\t},\n\t4: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Undead King\",\n\t\t\"base\": \"undead_king_base\",\n\t\t\"title\": \"THE CITADEL RISES\",\n\t\t\"description\": \"The Undead King and his Soul Citadel have awakened.\"\n\t}\n}"
	var new_rewards := "const MINEWARS_VICTORY_REWARDS := {\n\t2: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Shaman\",\n\t\t\"base\": \"shaman_base\",\n\t\t\"title\": \"THE SHAMAN ANSWERS\",\n\t\t\"description\": \"A second victory brings Shaman and the Shaman Lodge into the stronghold.\"\n\t},\n\t3: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Druid\",\n\t\t\"base\": \"druid_base\",\n\t\t\"title\": \"ROOTS BREAK THE STONE\",\n\t\t\"description\": \"Druid and the Druid Grove have awakened.\"\n\t},\n\t4: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Nerubian\",\n\t\t\"base\": \"nerubian_base\",\n\t\t\"title\": \"THE BROOD EMERGES\",\n\t\t\"description\": \"Nerubian and the Nerubian Nest have joined the war.\"\n\t},\n\t5: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Undead King\",\n\t\t\"base\": \"undead_king_base\",\n\t\t\"title\": \"THE CITADEL RISES\",\n\t\t\"description\": \"The Undead King and his Soul Citadel have awakened.\"\n\t}\n}"
	_patch("res://global.gd", old_rewards, new_rewards)

	_patch(
		"res://scripts/systems/preparation/preparation_world_controller.gd",
		"\t\t\tvar unlock_text := \"Complete the first level to unlock.\" if Global.FIRST_LEVEL_REWARD_HEROES.has(choice_id) else \"Reserved for a future unlock.\"",
		"\t\t\tvar unlock_text := \"Defeat the Goblin War Mech and its pilot.\" if choice_id == \"Mech\" else \"Earn more MineWars victories to unlock.\""
	)

	if failures.is_empty():
		print("BALANCE_FIRST_MECH_RUN_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if not source.contains(old_text):
		if source.contains(new_text):
			return
		failures.append("Patch target missing in %s: %s" % [path, old_text.left(100)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
