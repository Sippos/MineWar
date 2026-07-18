extends Node

func _ready() -> void:
	_patch_hero_rpg()
	_patch_player()
	_patch_world()
	_patch_expedition_controller()
	_patch_stronghold_ceremony()
	print("MINEWARS_RETENTION_JUICE_PASS_APPLIED")
	get_tree().quit()

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read: " + path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write: " + path)
		return
	file.store_string(text)
	file.close()

func _replace(source: String, old_text: String, new_text: String, label: String) -> String:
	if source.contains(new_text):
		return source
	if not source.contains(old_text):
		push_error("Missing patch anchor: " + label)
		return source
	return source.replace(old_text, new_text)

func _insert_before(source: String, anchor: String, insertion: String, label: String) -> String:
	if source.contains(insertion):
		return source
	var at := source.find(anchor)
	if at < 0:
		push_error("Missing insertion anchor: " + label)
		return source
	return source.insert(at, insertion)

func _patch_hero_rpg() -> void:
	var path := "res://hero_rpg_controller.gd"
	var source := _read(path)
	source = _replace(source,
		"func get_attack_interval() -> float:\n\tvar profile: Dictionary = _profile()\n\tvar agility_value: int = int(player.get(\"agility\"))\n\tvar attack_speed_multiplier: float = 1.0 + float(maxi(0, agility_value - 1)) * 0.035\n\treturn maxf(0.32, float(profile[\"base_attack_interval\"]) / attack_speed_multiplier)\n",
		"func get_attack_interval() -> float:\n\tvar profile: Dictionary = _profile()\n\tvar base: Dictionary = _base_stats()\n\tvar agility_value: int = int(player.get(\"agility\"))\n\tvar extra_agility := maxi(0, agility_value - int(base[\"agility\"]))\n\tvar attack_speed_multiplier: float = 1.0 + float(extra_agility) * 0.055\n\treturn maxf(0.26, float(profile[\"base_attack_interval\"]) / attack_speed_multiplier)\n",
		"attack interval identity")
	source = _replace(source,
		"func get_move_speed() -> float:\n\tvar agility_value: int = int(player.get(\"agility\"))\n\treturn float(player.get(\"base_speed\")) + float(maxi(0, agility_value - 1)) * 3.0\n\nfunc get_dig_time_multiplier() -> float:\n\tvar agility_value: int = int(player.get(\"agility\"))\n\tvar strength_value: int = int(player.get(\"strength\"))\n\tvar mining_speed: float = float(maxi(0, agility_value - 1)) * 0.025 + float(maxi(0, strength_value - 1)) * 0.015\n\treturn maxf(0.62, 1.0 / (1.0 + mining_speed))\n",
		"func get_move_speed() -> float:\n\tvar base: Dictionary = _base_stats()\n\tvar agility_value: int = int(player.get(\"agility\"))\n\tvar extra_agility := maxi(0, agility_value - int(base[\"agility\"]))\n\treturn float(player.get(\"base_speed\")) + float(extra_agility) * 5.5\n\nfunc get_dig_time_multiplier() -> float:\n\tvar base: Dictionary = _base_stats()\n\tvar agility_value: int = int(player.get(\"agility\"))\n\tvar strength_value: int = int(player.get(\"strength\"))\n\tvar extra_agility := maxi(0, agility_value - int(base[\"agility\"]))\n\tvar extra_strength := maxi(0, strength_value - int(base[\"strength\"]))\n\tvar mining_speed: float = float(extra_agility) * 0.050 + float(extra_strength) * 0.012\n\treturn maxf(0.48, 1.0 / (1.0 + mining_speed))\n\nfunc get_mining_force_multiplier(block_id: int) -> float:\n\tif block_id != 2 and block_id != 3:\n\t\treturn 1.0\n\tvar base: Dictionary = _base_stats()\n\tvar strength_value: int = int(player.get(\"strength\"))\n\tvar extra_strength := maxi(0, strength_value - int(base[\"strength\"]))\n\tvar reduction_per_point := 0.075 if block_id == 2 else 0.095\n\treturn maxf(0.42, 1.0 - float(extra_strength) * reduction_per_point)\n\nfunc get_build_identity() -> Dictionary:\n\tvar base: Dictionary = _base_stats()\n\tvar strength_extra := maxi(0, int(player.get(\"strength\")) - int(base[\"strength\"]))\n\tvar agility_extra := maxi(0, int(player.get(\"agility\")) - int(base[\"agility\"]))\n\tvar intelligence_extra := maxi(0, int(player.get(\"intelligence\")) - int(base[\"intelligence\"]))\n\tvar highest := maxi(strength_extra, maxi(agility_extra, intelligence_extra))\n\tif highest < 2:\n\t\treturn {\"title\": \"UNSHAPED\", \"description\": \"The next few gems will define this run.\", \"color\": Color(0.78, 0.82, 0.88)}\n\tvar leaders := 0\n\tleaders += 1 if strength_extra == highest else 0\n\tleaders += 1 if agility_extra == highest else 0\n\tleaders += 1 if intelligence_extra == highest else 0\n\tif leaders > 1:\n\t\treturn {\"title\": \"HYBRID DELVER\", \"description\": \"Balanced mining, combat, and utility.\", \"color\": Color(0.78, 0.72, 1.0)}\n\tif strength_extra == highest:\n\t\tvar title := \"LOADBEARER\" if highest < 5 else (\"EARTHBREAKER\" if highest < 8 else \"MOUNTAIN KING\")\n\t\treturn {\"title\": title, \"description\": \"Heavy loads, brutal melee, and hard-rock force.\", \"color\": Color(1.0, 0.48, 0.24)}\n\tif agility_extra == highest:\n\t\tvar title := \"SCOUT MINER\" if highest < 5 else (\"VEIN RUNNER\" if highest < 8 else \"CAVE BLUR\")\n\t\treturn {\"title\": title, \"description\": \"Fast digging, rapid attacks, and safer returns.\", \"color\": Color(0.35, 1.0, 0.58)}\n\tvar title := \"PROSPECTOR\" if highest < 5 else (\"RUNECASTER\" if highest < 8 else \"ARCANE ENGINE\")\n\treturn {\"title\": title, \"description\": \"Stronger utility, shorter cooldowns, and empowered summons.\", \"color\": Color(0.35, 0.72, 1.0)}\n",
		"move dig and build identity")
	source = _replace(source,
		"func get_spell_power_multiplier() -> float:\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\treturn 1.0 + float(maxi(0, intelligence_value - 1)) * 0.035\n\nfunc get_summon_power_multiplier() -> float:\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\treturn 1.0 + float(maxi(0, intelligence_value - 1)) * 0.030\n\nfunc get_cooldown_multiplier() -> float:\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\tvar reduction: float = minf(0.25, float(maxi(0, intelligence_value - 1)) * 0.0125)\n\treturn 1.0 - reduction\n\nfunc get_duration_multiplier() -> float:\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\treturn 1.0 + float(maxi(0, intelligence_value - 1)) * 0.015\n",
		"func get_spell_power_multiplier() -> float:\n\tvar base: Dictionary = _base_stats()\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\tvar extra_intelligence := maxi(0, intelligence_value - int(base[\"intelligence\"]))\n\treturn 1.0 + float(extra_intelligence) * 0.065\n\nfunc get_summon_power_multiplier() -> float:\n\tvar base: Dictionary = _base_stats()\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\tvar extra_intelligence := maxi(0, intelligence_value - int(base[\"intelligence\"]))\n\treturn 1.0 + float(extra_intelligence) * 0.055\n\nfunc get_cooldown_multiplier() -> float:\n\tvar base: Dictionary = _base_stats()\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\tvar extra_intelligence := maxi(0, intelligence_value - int(base[\"intelligence\"]))\n\tvar reduction: float = minf(0.42, float(extra_intelligence) * 0.028)\n\treturn 1.0 - reduction\n\nfunc get_duration_multiplier() -> float:\n\tvar base: Dictionary = _base_stats()\n\tvar intelligence_value: int = int(player.get(\"intelligence\"))\n\tvar extra_intelligence := maxi(0, intelligence_value - int(base[\"intelligence\"]))\n\treturn 1.0 + float(extra_intelligence) * 0.030\n",
		"intelligence identity")
	source = _replace(source,
		"func scale_physical_ability_damage(base_damage: int) -> int:\n\tvar base: Dictionary = _base_stats()\n\tvar strength_value: int = int(player.get(\"strength\"))\n\tvar extra_strength: int = maxi(0, strength_value - int(base[\"strength\"]))\n\tvar multiplier: float = 1.0 + float(extra_strength) * 0.025\n\tif get_primary_attribute() == \"strength\":\n\t\tmultiplier += float(extra_strength) * 0.015\n\treturn maxi(1, int(round(float(base_damage) * multiplier)))\n",
		"func scale_physical_ability_damage(base_damage: int) -> int:\n\tvar base: Dictionary = _base_stats()\n\tvar strength_value: int = int(player.get(\"strength\"))\n\tvar extra_strength: int = maxi(0, strength_value - int(base[\"strength\"]))\n\tvar multiplier: float = 1.0 + float(extra_strength) * 0.045\n\tif get_primary_attribute() == \"strength\":\n\t\tmultiplier += float(extra_strength) * 0.020\n\treturn maxi(1, int(round(float(base_damage) * multiplier)))\n",
		"strength ability identity")
	_write(path, source)

func _patch_player() -> void:
	var path := "res://player.gd"
	var source := _read(path)
	source = _replace(source, "const STRENGTH_CARRY_STEP := 3", "const STRENGTH_CARRY_STEP := 2", "strength carrying threshold")
	source = _replace(source,
		"\t\t\t\t\tvar current_target_dig_time: float = calculated_dig_time * get_block_hardness_multiplier(block_id)\n",
		"\t\t\t\t\tvar hardness_multiplier := get_block_hardness_multiplier(block_id)\n\t\t\t\t\tif rpg_mining != null and rpg_mining.has_method(\"get_mining_force_multiplier\"):\n\t\t\t\t\t\thardness_multiplier *= float(rpg_mining.call(\"get_mining_force_multiplier\", block_id))\n\t\t\t\t\tvar current_target_dig_time: float = calculated_dig_time * hardness_multiplier\n",
		"strength hard rock force")
	source = _replace(source,
		"\t\t\t\t\t\tvar cell_had_gem = get_parent().has_gem(cell)\n\t\t\t\t\t\tif get_parent().has_method(\"notify_tutorial_cell_dug\"):\n",
		"\t\t\t\t\t\tvar cell_had_gem = get_parent().has_gem(cell)\n\t\t\t\t\t\tif cell_had_gem and get_parent().has_method(\"notify_minewars_gem_dug\"):\n\t\t\t\t\t\t\tget_parent().notify_minewars_gem_dug(cell)\n\t\t\t\t\t\tif get_parent().has_method(\"notify_tutorial_cell_dug\"):\n",
		"direct objective mining event")
	_write(path, source)

func _patch_world() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var source := _read(path)
	var insertion := "func notify_minewars_gem_dug(cell: Vector2i) -> void:\n\tif not bool(get_meta(\"minewars_expedition\", false)):\n\t\treturn\n\tvar controller := get_node_or_null(\"SiegeModeController\")\n\tif controller != null and controller.has_method(\"notify_objective_gem_dug\"):\n\t\tcontroller.call(\"notify_objective_gem_dug\", cell)\n\n"
	source = _insert_before(source, "func notify_tutorial_cell_dug", insertion, "world objective forwarder")
	_write(path, source)

func _patch_expedition_controller() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	var source := _read(path)
	source = _replace(source,
		"var objective_missed_announced := false\nvar boss_phase := 0\nvar ui_layer: CanvasLayer\nvar status_label: Label\nvar objective_label: Label\n",
		"var objective_missed_announced := false\nvar objective_dug_cells: Dictionary = {}\nvar boss_phase := 0\nvar ui_layer: CanvasLayer\nvar status_label: Label\nvar build_label: Label\nvar objective_label: Label\n",
		"objective event and build label state")
	source = _replace(source,
		"\tobjective_missed_announced = false\n\tworld.set_meta(\"minewars_objective_complete\", false)\n",
		"\tobjective_missed_announced = false\n\tobjective_dug_cells.clear()\n\tworld.set_meta(\"minewars_objective_complete\", false)\n",
		"objective event reset")
	var event_functions := "func notify_objective_gem_dug(cell: Vector2i) -> void:\n\tif phase != Phase.MINING or objective_completed or objective_dug_cells.has(cell):\n\t\treturn\n\tif not _is_current_motherlode_cell(cell):\n\t\treturn\n\tobjective_dug_cells[cell] = true\n\tobjective_progress = mini(objective_progress + 1, int(STAGE_MOTHERLODE_COUNTS.get(stage_number, objective_progress + 1)))\n\tworld.set_meta(\"minewars_objective_progress\", objective_progress)\n\tworld.set_meta(\"minewars_objective_target\", _objective_target())\n\tif hud and hud.has_method(\"show_notice\") and not objective_completed:\n\t\thud.show_notice(\"%s  %d/%d — keep pushing or bank the partial haul.\" % [_objective_title(), mini(objective_progress, _objective_target()), _objective_target()], 2.0)\n\tif objective_progress >= _objective_target():\n\t\t_complete_stage_objective()\n\nfunc _is_current_motherlode_cell(cell: Vector2i) -> bool:\n\tvar motherlodes_value: Variant = world.get(\"minewars_motherlodes\")\n\tif not motherlodes_value is Dictionary:\n\t\treturn false\n\tvar motherlodes: Dictionary = motherlodes_value\n\tif not motherlodes.has(stage_number):\n\t\treturn false\n\tvar center: Vector2i = motherlodes[stage_number]\n\tvar total := int(STAGE_MOTHERLODE_COUNTS.get(stage_number, 0))\n\tfor index in range(total):\n\t\tif cell == center + MOTHERLODE_PATTERN[index % MOTHERLODE_PATTERN.size()]:\n\t\t\treturn true\n\treturn false\n\n"
	source = _insert_before(source, "func _update_stage_objective()", event_functions, "direct objective event functions")
	source = _replace(source,
		"\tobjective_progress = clampi(total - remaining, 0, total)\n",
		"\tobjective_progress = maxi(objective_progress, clampi(total - remaining, 0, total))\n",
		"objective reconciliation")
	source = _replace(source,
		"\t_award_objective_reward()\n\tif hud and hud.has_method(\"show_notice\"):\n",
		"\t_award_objective_reward()\n\t_play_objective_completion_feedback()\n\tif hud and hud.has_method(\"show_notice\"):\n",
		"objective celebration call")
	source = _replace(source,
		"\tstatus_label = Label.new()\n\tstatus_label.add_theme_font_size_override(\"font_size\", 13)\n\tstack.add_child(status_label)\n\tobjective_label = Label.new()\n",
		"\tstatus_label = Label.new()\n\tstatus_label.add_theme_font_size_override(\"font_size\", 13)\n\tstack.add_child(status_label)\n\tbuild_label = Label.new()\n\tbuild_label.add_theme_font_size_override(\"font_size\", 12)\n\tstack.add_child(build_label)\n\tobjective_label = Label.new()\n",
		"build label creation")
	source = _replace(source,
		"\tvar depth := _player_depth()\n\t_update_objective_label()\n",
		"\tvar depth := _player_depth()\n\t_update_build_label()\n\t_update_objective_label()\n",
		"build label update call")
	var feedback_functions := "func _update_build_label() -> void:\n\tif build_label == null or player == null:\n\t\treturn\n\tvar rpg := player.get_node_or_null(\"HeroRPGController\")\n\tif rpg == null or not rpg.has_method(\"get_build_identity\"):\n\t\tbuild_label.text = \"BUILD • STR %d  AGI %d  INT %d\" % [int(player.get(\"strength\")), int(player.get(\"agility\")), int(player.get(\"intelligence\"))]\n\t\treturn\n\tvar identity: Dictionary = rpg.call(\"get_build_identity\")\n\tbuild_label.text = \"BUILD • %s — %s\" % [str(identity.get(\"title\", \"UNSHAPED\")), str(identity.get(\"description\", \"\"))]\n\tbuild_label.add_theme_color_override(\"font_color\", identity.get(\"color\", Color.WHITE))\n\nfunc _play_objective_completion_feedback() -> void:\n\tif ui_layer == null or not is_instance_valid(ui_layer):\n\t\treturn\n\tvar viewport_size := get_viewport().get_visible_rect().size\n\tvar flash := ColorRect.new()\n\tflash.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tflash.position = Vector2.ZERO\n\tflash.size = viewport_size\n\tflash.color = Color(0.25, 0.9, 1.0, 0.0)\n\tui_layer.add_child(flash)\n\tvar flash_tween := create_tween()\n\tflash_tween.tween_property(flash, \"color:a\", 0.28, 0.08)\n\tflash_tween.tween_property(flash, \"color:a\", 0.0, 0.34)\n\tflash_tween.finished.connect(flash.queue_free)\n\n\tvar banner := PanelContainer.new()\n\tbanner.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tbanner.custom_minimum_size = Vector2(520, 110)\n\tbanner.position = Vector2((viewport_size.x - 520.0) * 0.5, viewport_size.y * 0.24)\n\tbanner.pivot_offset = Vector2(260, 55)\n\tbanner.scale = Vector2(0.72, 0.72)\n\tbanner.modulate = Color(1, 1, 1, 0)\n\tui_layer.add_child(banner)\n\tvar margin := MarginContainer.new()\n\tmargin.add_theme_constant_override(\"margin_left\", 18)\n\tmargin.add_theme_constant_override(\"margin_right\", 18)\n\tmargin.add_theme_constant_override(\"margin_top\", 12)\n\tmargin.add_theme_constant_override(\"margin_bottom\", 12)\n\tbanner.add_child(margin)\n\tvar stack := VBoxContainer.new()\n\tstack.alignment = BoxContainer.ALIGNMENT_CENTER\n\tmargin.add_child(stack)\n\tvar title := Label.new()\n\ttitle.text = \"OBJECTIVE SECURED • %s\" % _objective_title()\n\ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\ttitle.add_theme_font_size_override(\"font_size\", 24)\n\ttitle.add_theme_color_override(\"font_color\", Color(0.45, 0.96, 1.0))\n\tstack.add_child(title)\n\tvar reward := Label.new()\n\treward.text = _objective_reward_text() + \" — RETURN IT TO THE BASTION\"\n\treward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\treward.add_theme_font_size_override(\"font_size\", 14)\n\tstack.add_child(reward)\n\tvar banner_tween := create_tween()\n\tbanner_tween.set_parallel(true)\n\tbanner_tween.tween_property(banner, \"modulate\", Color.WHITE, 0.14)\n\tbanner_tween.tween_property(banner, \"scale\", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\tbanner_tween.chain().tween_interval(1.55)\n\tbanner_tween.chain().tween_property(banner, \"modulate:a\", 0.0, 0.28)\n\tbanner_tween.finished.connect(banner.queue_free)\n\n\tvar camera := player.get_node_or_null(\"Camera2D\") as Camera2D\n\tif camera != null:\n\t\tvar rest := camera.offset\n\t\tvar shake := create_tween()\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(7, -4), 0.045)\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(-6, 5), 0.045)\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(4, 3), 0.045)\n\t\tshake.tween_property(camera, \"offset\", rest, 0.08)\n\tvar pulse := create_tween()\n\tpulse.tween_property(player, \"scale\", Vector2(1.16, 1.16), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\tpulse.tween_property(player, \"scale\", Vector2.ONE, 0.18)\n\n"
	source = _insert_before(source, "func _danger_text()", feedback_functions, "objective completion and build identity UI")
	_write(path, source)

func _patch_stronghold_ceremony() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var source := _read(path)
	source = _replace(source,
		"\tfor reward_value in rewards:\n\t\tvar reward: Dictionary = reward_value\n\t\tvar banner := PanelContainer.new()\n",
		"\tfor reward_value in rewards:\n\t\tvar reward: Dictionary = reward_value\n\t\t_focus_unlock_target(reward)\n\t\t_play_unlock_world_burst(reward)\n\t\tvar banner := PanelContainer.new()\n",
		"stronghold ceremony world focus")
	var helpers := "func _focus_unlock_target(reward: Dictionary) -> void:\n\tif hub_camera == null or world == null:\n\t\treturn\n\tvar target_position := Vector2.ZERO\n\tvar hero_name := str(reward.get(\"hero\", \"\"))\n\tif not hero_name.is_empty():\n\t\tvar shrine := world.get_node_or_null(\"PhysicalHeroShrines/\" + hero_name.replace(\" \", \"\") + \"Shrine\") as Node2D\n\t\tif shrine != null:\n\t\t\ttarget_position = shrine.global_position\n\tvar home := Vector2(0, 20)\n\tvar pan := create_tween().set_parallel(true)\n\tpan.tween_property(hub_camera, \"position\", target_position if target_position != Vector2.ZERO else home, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)\n\tpan.tween_property(hub_camera, \"zoom\", Vector2(1.02, 1.02), 0.42)\n\t_return_unlock_camera_later(home)\n\nfunc _return_unlock_camera_later(home: Vector2) -> void:\n\tawait get_tree().create_timer(2.7).timeout\n\tif hub_camera == null or not is_instance_valid(hub_camera):\n\t\treturn\n\tvar restore := create_tween().set_parallel(true)\n\trestore.tween_property(hub_camera, \"position\", home, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)\n\trestore.tween_property(hub_camera, \"zoom\", Vector2(0.82, 0.82), 0.45)\n\nfunc _play_unlock_world_burst(reward: Dictionary) -> void:\n\tif world == null:\n\t\treturn\n\tvar origin := Vector2.ZERO\n\tvar hero_name := str(reward.get(\"hero\", \"\"))\n\tif not hero_name.is_empty():\n\t\tvar shrine := world.get_node_or_null(\"PhysicalHeroShrines/\" + hero_name.replace(\" \", \"\") + \"Shrine\") as Node2D\n\t\tif shrine != null:\n\t\t\torigin = shrine.global_position\n\tvar burst := Node2D.new()\n\tburst.name = \"UnlockWorldBurst\"\n\tburst.global_position = origin\n\tburst.z_index = 30\n\tworld.add_child(burst)\n\tfor ring_index in range(3):\n\t\tvar ring := Line2D.new()\n\t\tring.width = 5.0 - float(ring_index)\n\t\tring.default_color = Color(0.4 + float(ring_index) * 0.2, 0.78, 1.0, 0.9)\n\t\tvar points := PackedVector2Array()\n\t\tfor index in range(33):\n\t\t\tpoints.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * (24.0 + float(ring_index) * 12.0))\n\t\tring.points = points\n\t\tring.scale = Vector2(0.25, 0.25)\n\t\tburst.add_child(ring)\n\t\tvar expand := create_tween().set_parallel(true)\n\t\texpand.tween_property(ring, \"scale\", Vector2(1.65, 1.65), 0.7 + float(ring_index) * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)\n\t\texpand.tween_property(ring, \"modulate:a\", 0.0, 0.7 + float(ring_index) * 0.12)\n\tawait get_tree().create_timer(1.15).timeout\n\tif is_instance_valid(burst):\n\t\tburst.queue_free()\n\n"
	source = _insert_before(source, "func _show_locked_message", helpers, "stronghold ceremony helpers")
	_write(path, source)
