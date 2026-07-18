extends Node

var failures := 0

func _ready() -> void:
	_patch_global_progression()
	if failures == 0:
		print("MINEWARS_PROGRESSION_POLISH_APPLIED")
		get_tree().quit(0)
	else:
		push_error("MINEWARS_PROGRESSION_POLISH_FAILED: %d replacements missing" % failures)
		get_tree().quit(1)

func _replace_required(source: String, old_text: String, new_text: String, label: String) -> String:
	if not source.contains(old_text):
		failures += 1
		push_error("Missing progression patch target: " + label)
		return source
	return source.replace(old_text, new_text)

func _patch_global_progression() -> void:
	var path := "res://global.gd"
	var source := FileAccess.get_file_as_string(path)

	source = _replace_required(source,
		"const DEFAULT_UNLOCKED_HEROES = [\"Dwarf\"]\nconst SINGLE_PLAYER_PLAYTEST_HEROES = [\"Shaman\"]\nconst FIRST_LEVEL_REWARD_HEROES = [\"Nerubian\", \"Druid\", \"Undead King\"]",
		"const DEFAULT_UNLOCKED_HEROES = [\"Dwarf\"]\nconst DEFAULT_UNLOCKED_BASES = [\"default_base\"]\nconst FIRST_RUN_REWARD := {\n\t\"type\": \"workshop\",\n\t\"title\": \"LEGACY FORGE AWAKENED\",\n\t\"description\": \"The bastion can now spend Legacy Ore on permanent improvements.\"\n}\nconst MINEWARS_VICTORY_REWARDS := {\n\t1: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Shaman\",\n\t\t\"base\": \"shaman_base\",\n\t\t\"title\": \"THE SHAMAN ANSWERS\",\n\t\t\"description\": \"Shaman and the Shaman Lodge have joined the stronghold.\"\n\t},\n\t2: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Druid\",\n\t\t\"base\": \"druid_base\",\n\t\t\"title\": \"ROOTS BREAK THE STONE\",\n\t\t\"description\": \"Druid and the Druid Grove have awakened.\"\n\t},\n\t3: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Nerubian\",\n\t\t\"base\": \"nerubian_base\",\n\t\t\"title\": \"THE BROOD EMERGES\",\n\t\t\"description\": \"Nerubian and the Nerubian Nest have joined the war.\"\n\t},\n\t4: {\n\t\t\"type\": \"hero_base\",\n\t\t\"hero\": \"Undead King\",\n\t\t\"base\": \"undead_king_base\",\n\t\t\"title\": \"THE CITADEL RISES\",\n\t\t\"description\": \"The Undead King and his Soul Citadel have awakened.\"\n\t}\n}",
		"progression constants")

	source = _replace_required(source,
		"var unlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()\nvar first_level_beaten = false\nvar current_hero = DEFAULT_HERO_ID\nvar hero_p1 = DEFAULT_HERO_ID\nvar hero_p2 = DEFAULT_HERO_ID\nvar selected_hero_id := DEFAULT_HERO_ID\nvar selected_base_id := DEFAULT_BASE_ID\nvar prototype_onboarding_completed := false\nvar legacy_ore := 0\nvar last_run_legacy_ore_earned := 0",
		"var unlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()\nvar unlocked_bases = DEFAULT_UNLOCKED_BASES.duplicate()\nvar first_level_beaten = false\nvar minewars_runs_completed := 0\nvar minewars_victories := 0\nvar current_hero = DEFAULT_HERO_ID\nvar hero_p1 = DEFAULT_HERO_ID\nvar hero_p2 = DEFAULT_HERO_ID\nvar selected_hero_id := DEFAULT_HERO_ID\nvar selected_base_id := DEFAULT_BASE_ID\nvar prototype_onboarding_completed := false\nvar legacy_ore := 0\nvar last_run_legacy_ore_earned := 0\nvar pending_unlock_rewards: Array = []\nvar last_unlock_rewards: Array = []",
		"progression state")

	source = _replace_required(source,
		"func is_hero_playable_in_single_player(hero_name: String) -> bool:\n\treturn is_hero_unlocked(hero_name) or SINGLE_PLAYER_PLAYTEST_HEROES.has(hero_name)\n\nfunc unlock_hero(hero_name: String) -> void:\n\tif not hero_data.has(hero_name):\n\t\treturn\n\tif not unlocked_heroes.has(hero_name):\n\t\tunlocked_heroes.append(hero_name)\n\t\tprint(\"Unlocked Hero: \", hero_name)\n\t\tsave_game()\n\nfunc mark_first_level_beaten() -> void:\n\tfirst_level_beaten = true\n\tvar changed = false\n\tfor hero_name in FIRST_LEVEL_REWARD_HEROES:\n\t\tif hero_data.has(hero_name) and not unlocked_heroes.has(hero_name):\n\t\t\tunlocked_heroes.append(hero_name)\n\t\t\tchanged = true\n\tif changed:\n\t\tprint(\"First level beaten: unlocked extra heroes\")\n\tsave_game()",
		"func is_hero_playable_in_single_player(hero_name: String) -> bool:\n\treturn is_hero_unlocked(hero_name)\n\nfunc is_base_unlocked(base_id: String) -> bool:\n\treturn unlocked_bases.has(base_id)\n\nfunc is_legacy_workshop_unlocked() -> bool:\n\treturn minewars_runs_completed > 0\n\nfunc unlock_hero(hero_name: String) -> void:\n\tif not hero_data.has(hero_name):\n\t\treturn\n\tif not unlocked_heroes.has(hero_name):\n\t\tunlocked_heroes.append(hero_name)\n\t\tprint(\"Unlocked Hero: \", hero_name)\n\t\tsave_game()\n\nfunc unlock_base(base_id: String) -> void:\n\tif not base_data.has(base_id):\n\t\treturn\n\tif not unlocked_bases.has(base_id):\n\t\tunlocked_bases.append(base_id)\n\t\tprint(\"Unlocked Base: \", base_id)\n\t\tsave_game()\n\nfunc record_minewars_result(victory: bool) -> Array:\n\tminewars_runs_completed += 1\n\tlast_unlock_rewards = []\n\tif minewars_runs_completed == 1:\n\t\t_queue_progression_reward(FIRST_RUN_REWARD)\n\tif victory:\n\t\tminewars_victories += 1\n\t\tfirst_level_beaten = true\n\t\tvar milestone: Dictionary = MINEWARS_VICTORY_REWARDS.get(minewars_victories, {})\n\t\tif not milestone.is_empty():\n\t\t\tvar hero_name := str(milestone.get(\"hero\", \"\"))\n\t\t\tvar base_id := str(milestone.get(\"base\", \"\"))\n\t\t\tif not hero_name.is_empty() and hero_data.has(hero_name) and not unlocked_heroes.has(hero_name):\n\t\t\t\tunlocked_heroes.append(hero_name)\n\t\t\tif not base_id.is_empty() and base_data.has(base_id) and not unlocked_bases.has(base_id):\n\t\t\t\tunlocked_bases.append(base_id)\n\t\t\t_queue_progression_reward(milestone)\n\tsave_game()\n\treturn last_unlock_rewards.duplicate(true)\n\nfunc _queue_progression_reward(reward: Dictionary) -> void:\n\tvar reward_copy := reward.duplicate(true)\n\tlast_unlock_rewards.append(reward_copy)\n\tpending_unlock_rewards.append(reward_copy.duplicate(true))\n\nfunc consume_pending_unlock_rewards() -> Array:\n\tvar rewards := pending_unlock_rewards.duplicate(true)\n\tpending_unlock_rewards.clear()\n\tif not rewards.is_empty():\n\t\tsave_game()\n\treturn rewards\n\nfunc mark_first_level_beaten() -> void:\n\tfirst_level_beaten = true\n\tminewars_victories = maxi(minewars_victories, 1)\n\t_apply_milestone_unlocks()\n\tsave_game()",
		"progression methods")

	source = _replace_required(source,
		"\t\tfile.store_var({\n\t\t\t\"unlocked_heroes\": unlocked_heroes,\n\t\t\t\"first_level_beaten\": first_level_beaten,\n\t\t\t\"selected_hero_id\": selected_hero_id,\n\t\t\t\"selected_base_id\": selected_base_id,\n\t\t\t\"prototype_onboarding_completed\": prototype_onboarding_completed,\n\t\t\t\"legacy_ore\": legacy_ore,\n\t\t\t\"permanent_upgrade_levels\": permanent_upgrade_levels\n\t\t})",
		"\t\tfile.store_var({\n\t\t\t\"unlocked_heroes\": unlocked_heroes,\n\t\t\t\"unlocked_bases\": unlocked_bases,\n\t\t\t\"first_level_beaten\": first_level_beaten,\n\t\t\t\"minewars_runs_completed\": minewars_runs_completed,\n\t\t\t\"minewars_victories\": minewars_victories,\n\t\t\t\"selected_hero_id\": selected_hero_id,\n\t\t\t\"selected_base_id\": selected_base_id,\n\t\t\t\"prototype_onboarding_completed\": prototype_onboarding_completed,\n\t\t\t\"legacy_ore\": legacy_ore,\n\t\t\t\"permanent_upgrade_levels\": permanent_upgrade_levels,\n\t\t\t\"pending_unlock_rewards\": pending_unlock_rewards\n\t\t})",
		"save fields")

	source = _replace_required(source,
		"\t\t\t\tif loaded.has(\"unlocked_heroes\") and typeof(loaded[\"unlocked_heroes\"]) == TYPE_ARRAY:\n\t\t\t\t\tunlocked_heroes = loaded[\"unlocked_heroes\"]\n\t\t\t\tif loaded.has(\"first_level_beaten\"):\n\t\t\t\t\tfirst_level_beaten = bool(loaded[\"first_level_beaten\"])",
		"\t\t\t\tif loaded.has(\"unlocked_heroes\") and typeof(loaded[\"unlocked_heroes\"]) == TYPE_ARRAY:\n\t\t\t\t\tunlocked_heroes = loaded[\"unlocked_heroes\"]\n\t\t\t\tif loaded.has(\"unlocked_bases\") and typeof(loaded[\"unlocked_bases\"]) == TYPE_ARRAY:\n\t\t\t\t\tunlocked_bases = loaded[\"unlocked_bases\"]\n\t\t\t\tif loaded.has(\"first_level_beaten\"):\n\t\t\t\t\tfirst_level_beaten = bool(loaded[\"first_level_beaten\"])\n\t\t\t\tif loaded.has(\"minewars_runs_completed\"):\n\t\t\t\t\tminewars_runs_completed = maxi(0, int(loaded[\"minewars_runs_completed\"]))\n\t\t\t\tif loaded.has(\"minewars_victories\"):\n\t\t\t\t\tminewars_victories = maxi(0, int(loaded[\"minewars_victories\"]))",
		"load progression fields")

	source = _replace_required(source,
		"\t\t\t\tif loaded.has(\"permanent_upgrade_levels\") and typeof(loaded[\"permanent_upgrade_levels\"]) == TYPE_DICTIONARY:\n\t\t\t\t\tvar loaded_upgrades: Dictionary = loaded[\"permanent_upgrade_levels\"]\n\t\t\t\t\tfor upgrade_id in PERMANENT_UPGRADE_IDS:\n\t\t\t\t\t\tvar max_level := int(PERMANENT_UPGRADE_MAX_LEVELS[upgrade_id])\n\t\t\t\t\t\tpermanent_upgrade_levels[upgrade_id] = clampi(int(loaded_upgrades.get(upgrade_id, 0)), 0, max_level)\n\t\t\tfile.close()",
		"\t\t\t\tif loaded.has(\"permanent_upgrade_levels\") and typeof(loaded[\"permanent_upgrade_levels\"]) == TYPE_DICTIONARY:\n\t\t\t\t\tvar loaded_upgrades: Dictionary = loaded[\"permanent_upgrade_levels\"]\n\t\t\t\t\tfor upgrade_id in PERMANENT_UPGRADE_IDS:\n\t\t\t\t\t\tvar max_level := int(PERMANENT_UPGRADE_MAX_LEVELS[upgrade_id])\n\t\t\t\t\t\tpermanent_upgrade_levels[upgrade_id] = clampi(int(loaded_upgrades.get(upgrade_id, 0)), 0, max_level)\n\t\t\t\tif loaded.has(\"pending_unlock_rewards\") and typeof(loaded[\"pending_unlock_rewards\"]) == TYPE_ARRAY:\n\t\t\t\t\tpending_unlock_rewards = loaded[\"pending_unlock_rewards\"]\n\t\t\tfile.close()\n\tif first_level_beaten and minewars_victories == 0:\n\t\tminewars_victories = 1\n\tif minewars_victories > 0 and minewars_runs_completed == 0:\n\t\tminewars_runs_completed = minewars_victories",
		"load pending rewards and migration")

	var old_sanitize_start := source.find("func _sanitize_unlock_progress() -> void:")
	var old_sanitize_end := source.find("func mark_monster_seen", old_sanitize_start)
	if old_sanitize_start < 0 or old_sanitize_end < 0:
		failures += 1
		push_error("Missing progression patch target: sanitize function")
	else:
		var new_sanitize := "func _sanitize_unlock_progress() -> void:\n\tvar previous_heroes := unlocked_heroes.duplicate()\n\tvar previous_bases := unlocked_bases.duplicate()\n\tif first_level_beaten and minewars_victories == 0:\n\t\tminewars_victories = 1\n\tif minewars_victories > 0:\n\t\tfirst_level_beaten = true\n\tif minewars_runs_completed < minewars_victories:\n\t\tminewars_runs_completed = minewars_victories\n\tunlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()\n\tunlocked_bases = DEFAULT_UNLOCKED_BASES.duplicate()\n\t_apply_milestone_unlocks()\n\tif not unlocked_heroes.has(selected_hero_id):\n\t\tselected_hero_id = DEFAULT_HERO_ID\n\tif not unlocked_bases.has(selected_base_id):\n\t\tselected_base_id = DEFAULT_BASE_ID\n\tif previous_heroes != unlocked_heroes or previous_bases != unlocked_bases:\n\t\tsave_game()\n\nfunc _apply_milestone_unlocks() -> void:\n\tfor victory_number in range(1, minewars_victories + 1):\n\t\tvar milestone: Dictionary = MINEWARS_VICTORY_REWARDS.get(victory_number, {})\n\t\tif milestone.is_empty():\n\t\t\tcontinue\n\t\tvar hero_name := str(milestone.get(\"hero\", \"\"))\n\t\tvar base_id := str(milestone.get(\"base\", \"\"))\n\t\tif hero_data.has(hero_name) and not unlocked_heroes.has(hero_name):\n\t\t\tunlocked_heroes.append(hero_name)\n\t\tif base_data.has(base_id) and not unlocked_bases.has(base_id):\n\t\t\tunlocked_bases.append(base_id)\n\n"
		source = source.substr(0, old_sanitize_start) + new_sanitize + source.substr(old_sanitize_end)

	if failures == 0:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(source)
		file.close()
