extends Node

func _ready() -> void:
	var ok := _patch_global_progression()
	ok = _patch_single_player_hub() and ok
	if ok:
		print("STRONGHOLD_AMBIENCE_PATCH_OK")
	else:
		push_error("STRONGHOLD_AMBIENCE_PATCH_FAILED")
	get_tree().quit(0 if ok else 1)

func _patch_global_progression() -> bool:
	var path := "res://global.gd"
	var source := FileAccess.get_file_as_string(path)
	var original := source

	source = _replace_required(source,
		"}\nconst GAME_UI_THEME_PATH = \"res://assets/themes/global/global_theme.tres\"",
		"}\nconst STRONGHOLD_AMBIENCE_IDS := [\"dwarf_minecart\"]\nconst STRONGHOLD_AMBIENCE_MILESTONES := {\n\t\"Dwarf\": {\n\t\t2: {\n\t\t\t\"type\": \"stronghold_ambience\",\n\t\t\t\"ambience\": \"dwarf_minecart\",\n\t\t\t\"title\": \"DWARVEN RAILWAY ONLINE\",\n\t\t\t\"description\": \"Two victories with the Dwarf have brought the Bastion's minecart loop to life.\"\n\t\t}\n\t}\n}\nconst GAME_UI_THEME_PATH = \"res://assets/themes/global/global_theme.tres\"",
		"ambience milestone constants")

	source = _replace_required(source,
		"var minewars_victories := 0\nvar current_hero = DEFAULT_HERO_ID",
		"var minewars_victories := 0\nvar hero_victories: Dictionary = {}\nvar unlocked_stronghold_ambience: Array = []\nvar current_hero = DEFAULT_HERO_ID",
		"hero victory state")

	source = _replace_required(source,
		"func is_base_unlocked(base_id: String) -> bool:\n\treturn unlocked_bases.has(base_id)\n\nfunc is_legacy_workshop_unlocked() -> bool:",
		"func is_base_unlocked(base_id: String) -> bool:\n\treturn unlocked_bases.has(base_id)\n\nfunc get_hero_victories(hero_name: String) -> int:\n\treturn maxi(0, int(hero_victories.get(hero_name, 0)))\n\nfunc is_stronghold_ambience_unlocked(ambience_id: String) -> bool:\n\treturn unlocked_stronghold_ambience.has(ambience_id)\n\nfunc is_legacy_workshop_unlocked() -> bool:",
		"ambience query methods")

	source = _replace_required(source,
		"func record_minewars_result(victory: bool) -> Array:\n\tminewars_runs_completed += 1\n\tlast_unlock_rewards = []\n\tif minewars_runs_completed == 1:\n\t\t_queue_progression_reward(FIRST_RUN_REWARD)\n\tif victory:\n\t\tminewars_victories += 1\n\t\tfirst_level_beaten = true\n\t\tvar milestone: Dictionary = MINEWARS_VICTORY_REWARDS.get(minewars_victories, {})\n\t\tif not milestone.is_empty():\n\t\t\tvar hero_name := str(milestone.get(\"hero\", \"\"))\n\t\t\tvar base_id := str(milestone.get(\"base\", \"\"))\n\t\t\tif not hero_name.is_empty() and hero_data.has(hero_name) and not unlocked_heroes.has(hero_name):\n\t\t\t\tunlocked_heroes.append(hero_name)\n\t\t\tif not base_id.is_empty() and base_data.has(base_id) and not unlocked_bases.has(base_id):\n\t\t\t\tunlocked_bases.append(base_id)\n\t\t\t_queue_progression_reward(milestone)\n\tsave_game()\n\treturn last_unlock_rewards.duplicate(true)",
		"func record_minewars_result(victory: bool) -> Array:\n\tminewars_runs_completed += 1\n\tlast_unlock_rewards = []\n\tif minewars_runs_completed == 1:\n\t\t_queue_progression_reward(FIRST_RUN_REWARD)\n\tif victory:\n\t\tminewars_victories += 1\n\t\tvar victory_hero := current_hero\n\t\tif not hero_data.has(victory_hero):\n\t\t\tvictory_hero = selected_hero_id\n\t\thero_victories[victory_hero] = get_hero_victories(victory_hero) + 1\n\t\t_apply_hero_ambience_milestone(victory_hero, get_hero_victories(victory_hero), true)\n\t\tfirst_level_beaten = true\n\t\tvar milestone: Dictionary = MINEWARS_VICTORY_REWARDS.get(minewars_victories, {})\n\t\tif not milestone.is_empty():\n\t\t\tvar hero_name := str(milestone.get(\"hero\", \"\"))\n\t\t\tvar base_id := str(milestone.get(\"base\", \"\"))\n\t\t\tif not hero_name.is_empty() and hero_data.has(hero_name) and not unlocked_heroes.has(hero_name):\n\t\t\t\tunlocked_heroes.append(hero_name)\n\t\t\tif not base_id.is_empty() and base_data.has(base_id) and not unlocked_bases.has(base_id):\n\t\t\t\tunlocked_bases.append(base_id)\n\t\t\t_queue_progression_reward(milestone)\n\tsave_game()\n\treturn last_unlock_rewards.duplicate(true)",
		"hero-specific victory recording")

	source = _replace_required(source,
		"func _queue_progression_reward(reward: Dictionary) -> void:\n\tvar reward_copy := reward.duplicate(true)\n\tlast_unlock_rewards.append(reward_copy)\n\tpending_unlock_rewards.append(reward_copy.duplicate(true))\n\nfunc consume_pending_unlock_rewards() -> Array:",
		"func _queue_progression_reward(reward: Dictionary) -> void:\n\tvar reward_copy := reward.duplicate(true)\n\tlast_unlock_rewards.append(reward_copy)\n\tpending_unlock_rewards.append(reward_copy.duplicate(true))\n\nfunc _apply_hero_ambience_milestone(hero_name: String, victory_count: int, queue_reward: bool) -> void:\n\tvar hero_milestones_value = STRONGHOLD_AMBIENCE_MILESTONES.get(hero_name, {})\n\tif typeof(hero_milestones_value) != TYPE_DICTIONARY:\n\t\treturn\n\tvar hero_milestones: Dictionary = hero_milestones_value\n\tvar milestone_value = hero_milestones.get(victory_count, {})\n\tif typeof(milestone_value) != TYPE_DICTIONARY:\n\t\treturn\n\tvar milestone: Dictionary = milestone_value\n\tif milestone.is_empty():\n\t\treturn\n\tvar ambience_id := str(milestone.get(\"ambience\", \"\"))\n\tif ambience_id.is_empty() or not STRONGHOLD_AMBIENCE_IDS.has(ambience_id):\n\t\treturn\n\tif unlocked_stronghold_ambience.has(ambience_id):\n\t\treturn\n\tunlocked_stronghold_ambience.append(ambience_id)\n\tif queue_reward:\n\t\t_queue_progression_reward(milestone)\n\nfunc _apply_all_hero_ambience_milestones() -> void:\n\tfor hero_name_value in hero_victories.keys():\n\t\tvar hero_name := str(hero_name_value)\n\t\tvar victory_count := get_hero_victories(hero_name)\n\t\tvar hero_milestones_value = STRONGHOLD_AMBIENCE_MILESTONES.get(hero_name, {})\n\t\tif typeof(hero_milestones_value) != TYPE_DICTIONARY:\n\t\t\tcontinue\n\t\tvar hero_milestones: Dictionary = hero_milestones_value\n\t\tvar thresholds: Array = hero_milestones.keys()\n\t\tthresholds.sort()\n\t\tfor threshold_value in thresholds:\n\t\t\tvar threshold := int(threshold_value)\n\t\t\tif threshold <= victory_count:\n\t\t\t\t_apply_hero_ambience_milestone(hero_name, threshold, false)\n\nfunc consume_pending_unlock_rewards() -> Array:",
		"ambience milestone application")

	source = _replace_required(source,
		"\t\t\t\"minewars_victories\": minewars_victories,\n\t\t\t\"selected_hero_id\": selected_hero_id,",
		"\t\t\t\"minewars_victories\": minewars_victories,\n\t\t\t\"hero_victories\": hero_victories,\n\t\t\t\"unlocked_stronghold_ambience\": unlocked_stronghold_ambience,\n\t\t\t\"selected_hero_id\": selected_hero_id,",
		"ambience save data")

	source = _replace_required(source,
		"\t\t\t\tif loaded.has(\"minewars_victories\"):\n\t\t\t\t\tminewars_victories = maxi(0, int(loaded[\"minewars_victories\"]))\n\t\t\t\tif loaded.has(\"selected_hero_id\"):",
		"\t\t\t\tif loaded.has(\"minewars_victories\"):\n\t\t\t\t\tminewars_victories = maxi(0, int(loaded[\"minewars_victories\"]))\n\t\t\t\tif loaded.has(\"hero_victories\") and typeof(loaded[\"hero_victories\"]) == TYPE_DICTIONARY:\n\t\t\t\t\thero_victories = loaded[\"hero_victories\"]\n\t\t\t\tif loaded.has(\"unlocked_stronghold_ambience\") and typeof(loaded[\"unlocked_stronghold_ambience\"]) == TYPE_ARRAY:\n\t\t\t\t\tunlocked_stronghold_ambience = loaded[\"unlocked_stronghold_ambience\"]\n\t\t\t\tif loaded.has(\"selected_hero_id\"):",
		"ambience load data")

	source = _replace_required(source,
		"\tif minewars_victories > 0 and minewars_runs_completed == 0:\n\t\tminewars_runs_completed = minewars_victories\n\tapply_selected_loadout()",
		"\tif minewars_victories > 0 and minewars_runs_completed == 0:\n\t\tminewars_runs_completed = minewars_victories\n\t_apply_all_hero_ambience_milestones()\n\tapply_selected_loadout()",
		"ambience load reconciliation")

	source = _replace_required(source,
		"func _sanitize_unlock_progress() -> void:\n\tvar previous_heroes: Array = unlocked_heroes.duplicate()\n\tvar previous_bases: Array = unlocked_bases.duplicate()\n\tif first_level_beaten and minewars_victories == 0:\n\t\tminewars_victories = 1\n\tif minewars_victories > 0:\n\t\tfirst_level_beaten = true\n\tif minewars_runs_completed < minewars_victories:\n\t\tminewars_runs_completed = minewars_victories\n\tunlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()\n\tunlocked_bases = DEFAULT_UNLOCKED_BASES.duplicate()\n\t_apply_milestone_unlocks()\n\tif not unlocked_heroes.has(selected_hero_id):\n\t\tselected_hero_id = DEFAULT_HERO_ID\n\tif not unlocked_bases.has(selected_base_id):\n\t\tselected_base_id = DEFAULT_BASE_ID\n\tif previous_heroes != unlocked_heroes or previous_bases != unlocked_bases:\n\t\tsave_game()",
		"func _sanitize_unlock_progress() -> void:\n\tvar previous_heroes: Array = unlocked_heroes.duplicate()\n\tvar previous_bases: Array = unlocked_bases.duplicate()\n\tvar previous_hero_victories: Dictionary = hero_victories.duplicate(true)\n\tvar previous_ambience: Array = unlocked_stronghold_ambience.duplicate()\n\tif first_level_beaten and minewars_victories == 0:\n\t\tminewars_victories = 1\n\tif minewars_victories > 0:\n\t\tfirst_level_beaten = true\n\tif minewars_runs_completed < minewars_victories:\n\t\tminewars_runs_completed = minewars_victories\n\tvar sanitized_hero_victories: Dictionary = {}\n\tfor hero_name_value in hero_victories.keys():\n\t\tvar hero_name := str(hero_name_value)\n\t\tif hero_data.has(hero_name):\n\t\t\tvar victories := maxi(0, int(hero_victories[hero_name_value]))\n\t\t\tif victories > 0:\n\t\t\t\tsanitized_hero_victories[hero_name] = victories\n\thero_victories = sanitized_hero_victories\n\tvar sanitized_ambience: Array = []\n\tfor ambience_value in unlocked_stronghold_ambience:\n\t\tvar ambience_id := str(ambience_value)\n\t\tif STRONGHOLD_AMBIENCE_IDS.has(ambience_id) and not sanitized_ambience.has(ambience_id):\n\t\t\tsanitized_ambience.append(ambience_id)\n\tunlocked_stronghold_ambience = sanitized_ambience\n\tunlocked_heroes = DEFAULT_UNLOCKED_HEROES.duplicate()\n\tunlocked_bases = DEFAULT_UNLOCKED_BASES.duplicate()\n\t_apply_milestone_unlocks()\n\t_apply_all_hero_ambience_milestones()\n\tif not unlocked_heroes.has(selected_hero_id):\n\t\tselected_hero_id = DEFAULT_HERO_ID\n\tif not unlocked_bases.has(selected_base_id):\n\t\tselected_base_id = DEFAULT_BASE_ID\n\tif previous_heroes != unlocked_heroes or previous_bases != unlocked_bases or previous_hero_victories != hero_victories or previous_ambience != unlocked_stronghold_ambience:\n\t\tsave_game()",
		"ambience sanitization")

	if source == original:
		push_error("global.gd was not changed")
		return false
	return _write_source(path, source)

func _patch_single_player_hub() -> bool:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	var original := source

	source = _replace_required(source,
		"const LINE_WARS_CONTROLLER_SCRIPT := preload(\"res://scripts/systems/continuous_line_wars_controller.gd\")",
		"const LINE_WARS_CONTROLLER_SCRIPT := preload(\"res://scripts/systems/continuous_line_wars_controller.gd\")\nconst STRONGHOLD_AMBIENCE_SCRIPT := preload(\"res://scripts/systems/stronghold_ambience_controller.gd\")",
		"ambience controller preload")

	source = _replace_required(source,
		"var player_camera: Camera2D\nvar _committing := false",
		"var player_camera: Camera2D\nvar stronghold_ambience: Node2D\nvar _last_ambience_base_id := \"\"\nvar _committing := false",
		"ambience controller state")

	source = _replace_required(source,
		"\tif base.has_method(\"refresh_base_sprite\"):\n\t\tbase.refresh_base_sprite()\n\n\tplayer_camera = player.get_node_or_null(\"Camera2D\") as Camera2D",
		"\tif base.has_method(\"refresh_base_sprite\"):\n\t\tbase.refresh_base_sprite()\n\t_refresh_stronghold_ambience()\n\n\tplayer_camera = player.get_node_or_null(\"Camera2D\") as Camera2D",
		"initial ambience refresh")

	source = _replace_required(source,
		"func _process(_delta: float) -> void:\n\tif _committing or world == null or player == null:\n\t\treturn\n\tvar cell := block_layer.local_to_map(block_layer.to_local(player.global_position))",
		"func _process(_delta: float) -> void:\n\tif _committing or world == null or player == null:\n\t\treturn\n\tif Global.selected_base_id != _last_ambience_base_id:\n\t\t_refresh_stronghold_ambience()\n\tvar cell := block_layer.local_to_map(block_layer.to_local(player.global_position))",
		"live ambience refresh")

	source = _replace_required(source,
		"func _create_hub_camera() -> void:\n\thub_camera = Camera2D.new()\n\thub_camera.name = \"HeroHallCamera\"\n\thub_camera.position = Vector2(0, 20)\n\thub_camera.zoom = Vector2(0.82, 0.82)\n\thub_camera.position_smoothing_enabled = false\n\tworld.add_child(hub_camera)\n\thub_camera.enabled = true\n\nfunc _process(_delta: float) -> void:",
		"func _create_hub_camera() -> void:\n\thub_camera = Camera2D.new()\n\thub_camera.name = \"HeroHallCamera\"\n\thub_camera.position = Vector2(0, 20)\n\thub_camera.zoom = Vector2(0.82, 0.82)\n\thub_camera.position_smoothing_enabled = false\n\tworld.add_child(hub_camera)\n\thub_camera.enabled = true\n\nfunc _refresh_stronghold_ambience() -> void:\n\t_last_ambience_base_id = Global.selected_base_id\n\tvar should_show_dwarf_cart := Global.selected_base_id == Global.DEFAULT_BASE_ID and Global.is_stronghold_ambience_unlocked(\"dwarf_minecart\")\n\tif should_show_dwarf_cart and stronghold_ambience != null and is_instance_valid(stronghold_ambience):\n\t\treturn\n\tif stronghold_ambience != null and is_instance_valid(stronghold_ambience):\n\t\tstronghold_ambience.queue_free()\n\tstronghold_ambience = null\n\tif not should_show_dwarf_cart or world == null or base == null:\n\t\treturn\n\tvar ambience := Node2D.new()\n\tambience.name = \"StrongholdAmbience\"\n\tambience.set_script(STRONGHOLD_AMBIENCE_SCRIPT)\n\tambience.position = base.position\n\tworld.add_child(ambience)\n\tstronghold_ambience = ambience\n\nfunc _process(_delta: float) -> void:",
		"ambience spawn logic")

	if source == original:
		push_error("single_player_world_controller.gd was not changed")
		return false
	return _write_source(path, source)

func _replace_required(source: String, old_text: String, new_text: String, label: String) -> String:
	var matches := source.count(old_text)
	if matches != 1:
		push_error("Patch '%s' expected exactly one match, found %d" % [label, matches])
		return source
	return source.replace(old_text, new_text)

func _write_source(path: String, source: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(source)
	file.close()
	return true
