extends Node

func _replace_once(source: String, old_text: String, new_text: String, label: String) -> String:
	if not source.contains(old_text):
		push_error("Missing MineWars fairness patch target: %s" % label)
		return source
	return source.replace(old_text, new_text)

func _ready() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s" % path)
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()

	source = _replace_once(
		source,
		"const STAGE_CLEAR_GEM_REWARDS := {\n\t1: 1,\n\t2: 1,\n\t3: 2,\n}\n",
		"const STAGE_CLEAR_GEM_REWARDS := {\n\t1: 1,\n\t2: 1,\n\t3: 2,\n}\nconst STAGE_MUSTER_TIMES := {\n\t1: 10.0,\n\t2: 8.0,\n\t3: 6.0,\n\t4: 5.0,\n}\nconst STAGE_ENEMY_POWER_LEVELS := {\n\t1: 1,\n\t2: 3,\n\t3: 5,\n\t4: 8,\n}\n",
		"stage fairness constants"
	)

	source = _replace_once(
		source,
		"var wave_spawning := false\nvar warning_stage := -1\n",
		"var wave_spawning := false\nvar assault_muster_timer := 0.0\nvar assault_spawn_started := false\nvar warning_stage := -1\n",
		"muster state"
	)

	source = _replace_once(
		source,
		"func _process_attack() -> void:\n\tif not wave_spawning and _count_world_enemies() == 0:\n\t\t_complete_assault()\n",
		"func _process_attack() -> void:\n\tif assault_muster_timer > 0.0:\n\t\tassault_muster_timer = maxf(assault_muster_timer - get_process_delta_time(), 0.0)\n\t\tif assault_muster_timer <= 0.0 and not assault_spawn_started:\n\t\t\tassault_spawn_started = true\n\t\t\t_spawn_assault()\n\t\treturn\n\tif not assault_spawn_started:\n\t\tassault_spawn_started = true\n\t\t_spawn_assault()\n\t\treturn\n\tif not wave_spawning and _count_world_enemies() == 0:\n\t\t_complete_assault()\n",
		"attack muster processing"
	)

	source = _replace_once(
		source,
		"\tphase = Phase.ATTACK\n\twave_spawning = true\n\tworld.set_meta(\"wave_spawning\", true)\n",
		"\tphase = Phase.ATTACK\n\twave_spawning = true\n\tassault_muster_timer = float(STAGE_MUSTER_TIMES.get(stage_number, 6.0))\n\tassault_spawn_started = false\n\tworld.set_meta(\"wave_spawning\", true)\n",
		"start muster timer"
	)

	source = _replace_once(
		source,
		"\t\telse:\n\t\t\thud.show_notice(\"ASSAULT %d — return to the western breach and defend the bastion!\" % stage_number, 4.0)\n\t_spawn_assault()\n",
		"\t\telse:\n\t\t\thud.show_notice(\"ASSAULT %d — the breach opens in %d seconds. Return to the bastion now!\" % [stage_number, ceili(assault_muster_timer)], 4.8)\n",
		"deferred assault spawn"
	)

	source = _replace_once(
		source,
		"\t\tif enemy.has_method(\"initialize\"):\n\t\t\tvar enemy_type := int(roster[index])\n\t\t\tenemy.initialize(stage_number * 2, is_boss, enemy_type)\n",
		"\t\tif enemy.has_method(\"initialize\"):\n\t\t\tvar enemy_type := int(roster[index])\n\t\t\tvar power_level := int(STAGE_ENEMY_POWER_LEVELS.get(stage_number, stage_number))\n\t\t\tenemy.initialize(power_level, is_boss, enemy_type)\n",
		"enemy power curve"
	)

	source = _replace_once(
		source,
		"func _complete_assault() -> void:\n\t_award_stage_clear_reward(stage_number)\n",
		"func _complete_assault() -> void:\n\tassault_muster_timer = 0.0\n\tassault_spawn_started = false\n\t_award_stage_clear_reward(stage_number)\n",
		"reset muster state"
	)

	source = _replace_once(
		source,
		"\t\tPhase.ATTACK:\n\t\t\thud.update_wave_info(stage_number, -1.0, maximum, is_boss)\n",
		"\t\tPhase.ATTACK:\n\t\t\tif assault_muster_timer > 0.0:\n\t\t\t\thud.update_wave_info(stage_number, assault_muster_timer, float(STAGE_MUSTER_TIMES.get(stage_number, 6.0)), is_boss)\n\t\t\telse:\n\t\t\t\thud.update_wave_info(stage_number, -1.0, maximum, is_boss)\n",
		"muster HUD countdown"
	)

	source = _replace_once(
		source,
		"\tif phase == Phase.ATTACK:\n\t\tvar assault_title := \"BOSS ASSAULT\" if stage_number == FINAL_STAGE else \"ASSAULT %d/%d\" % [stage_number, FINAL_STAGE]\n\t\tstatus_label.text = \"%s  •  %s  •  Enemies %d\\nDepth %d  •  Carrying %d\" % [assault_title, _stage_name(stage_number), _count_world_enemies(), depth, carry_load]\n\t\thint_label.text = \"Fight at the western breach. The build you assembled during the expeditions is the defence.\"\n\t\treturn\n",
		"\tif phase == Phase.ATTACK:\n\t\tvar assault_title := \"BOSS ASSAULT\" if stage_number == FINAL_STAGE else \"ASSAULT %d/%d\" % [stage_number, FINAL_STAGE]\n\t\tif assault_muster_timer > 0.0:\n\t\t\tstatus_label.text = \"%s  •  %s  •  BREACH IN %d\\nDepth %d  •  Carrying %d\" % [assault_title, _stage_name(stage_number), ceili(assault_muster_timer), depth, carry_load]\n\t\t\thint_label.text = \"The enemy has not entered yet. Abandon the haul and reach the western breach before the countdown ends.\"\n\t\telse:\n\t\t\tstatus_label.text = \"%s  •  %s  •  Enemies %d\\nDepth %d  •  Carrying %d\" % [assault_title, _stage_name(stage_number), _count_world_enemies(), depth, carry_load]\n\t\t\thint_label.text = \"Fight at the western breach. The build you assembled during the expeditions is the defence.\"\n\t\treturn\n",
		"attack phase fairness UI"
	)

	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write %s" % path)
		get_tree().quit(1)
		return
	output.store_string(source)
	output.close()
	print("MINEWARS_RETURN_FAIRNESS_TUNED")
	get_tree().quit()
