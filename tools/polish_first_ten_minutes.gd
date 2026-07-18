extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch_single_player_hub()
	_patch_minewars_controller()
	_patch_hud_return_cue()
	_patch_first_crystal_feedback()
	if failures.is_empty():
		print("FIRST_TEN_MINUTES_POLISH_PATCH_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_single_player_hub() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	_replace_once(
		path,
		"var _last_locked_message := \"\"\n",
		"var _last_locked_message := \"\"\nvar first_run_guide_layer: CanvasLayer\nvar first_run_route_marker: Node2D\n"
	)
	_replace_once(
		path,
		"\t_configure_progression_signs()\n\t_set_initial_status()\n\tif not pending_rewards.is_empty():",
		"\t_configure_progression_signs()\n\t_set_initial_status()\n\tif Global.minewars_runs_completed == 0 and not Global.prototype_onboarding_completed:\n\t\t_create_first_run_stronghold_guide()\n\tif not pending_rewards.is_empty():"
	)
	_replace_once(
		path,
		"func _create_practice_gem_station() -> void:\n",
		"func _create_first_run_stronghold_guide() -> void:\n\tif world == null or block_layer == null or first_run_guide_layer != null:\n\t\treturn\n\tfirst_run_guide_layer = CanvasLayer.new()\n\tfirst_run_guide_layer.name = \"FirstRunStrongholdGuide\"\n\tfirst_run_guide_layer.layer = 45\n\tadd_child(first_run_guide_layer)\n\n\tvar panel := PanelContainer.new()\n\tpanel.set_anchors_preset(Control.PRESET_TOP_WIDE)\n\tpanel.offset_left = 120.0\n\tpanel.offset_top = 20.0\n\tpanel.offset_right = -120.0\n\tpanel.offset_bottom = 116.0\n\tpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tvar style := StyleBoxFlat.new()\n\tstyle.bg_color = Color(0.018, 0.055, 0.075, 0.96)\n\tstyle.border_color = Color(0.32, 0.9, 1.0, 0.92)\n\tstyle.set_border_width_all(2)\n\tstyle.set_corner_radius_all(10)\n\tstyle.shadow_color = Color(0, 0, 0, 0.62)\n\tstyle.shadow_size = 7\n\tpanel.add_theme_stylebox_override(\"panel\", style)\n\tfirst_run_guide_layer.add_child(panel)\n\tvar margin := MarginContainer.new()\n\tmargin.add_theme_constant_override(\"margin_left\", 18)\n\tmargin.add_theme_constant_override(\"margin_right\", 18)\n\tmargin.add_theme_constant_override(\"margin_top\", 10)\n\tmargin.add_theme_constant_override(\"margin_bottom\", 10)\n\tpanel.add_child(margin)\n\tvar stack := VBoxContainer.new()\n\tstack.alignment = BoxContainer.ALIGNMENT_CENTER\n\tstack.add_theme_constant_override(\"separation\", 2)\n\tmargin.add_child(stack)\n\tvar title := Label.new()\n\ttitle.text = \"YOUR FIRST EXPEDITION\"\n\ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\ttitle.add_theme_font_size_override(\"font_size\", 22)\n\ttitle.add_theme_color_override(\"font_color\", Color(0.58, 0.96, 1.0, 1.0))\n\tstack.add_child(title)\n\tvar body := Label.new()\n\tbody.text = \"Dwarf + Dwarf Bastion are ready. Walk DOWN into MineWars. The assault clock starts only after the short mining lesson.\"\n\tbody.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tbody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tbody.add_theme_font_size_override(\"font_size\", 13)\n\tbody.add_theme_color_override(\"font_color\", Color(0.9, 0.94, 0.98, 1.0))\n\tstack.add_child(body)\n\tpanel.modulate = Color(1, 1, 1, 0)\n\tpanel.scale = Vector2(0.94, 0.94)\n\tpanel.pivot_offset = Vector2(380, 48)\n\tvar reveal := create_tween().set_parallel(true)\n\treveal.tween_property(panel, \"modulate\", Color.WHITE, 0.28)\n\treveal.tween_property(panel, \"scale\", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\n\tfirst_run_route_marker = Node2D.new()\n\tfirst_run_route_marker.name = \"FirstRunMineWarsRoute\"\n\tfirst_run_route_marker.global_position = block_layer.to_global(block_layer.map_to_local(Vector2i(0, MINE_WARS_ENTRY_Y - 1)))\n\tfirst_run_route_marker.z_index = 35\n\tworld.add_child(first_run_route_marker)\n\tvar ring := Line2D.new()\n\tring.width = 5.0\n\tring.default_color = Color(0.3, 0.94, 1.0, 0.92)\n\tvar ring_points := PackedVector2Array()\n\tfor index in range(33):\n\t\tring_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * 42.0)\n\tring.points = ring_points\n\tfirst_run_route_marker.add_child(ring)\n\tvar arrow := Label.new()\n\tarrow.text = \"▼  ENTER MINEWARS  ▼\"\n\tarrow.position = Vector2(-120, -82)\n\tarrow.size = Vector2(240, 32)\n\tarrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tarrow.add_theme_font_size_override(\"font_size\", 15)\n\tarrow.add_theme_color_override(\"font_color\", Color(0.54, 0.98, 1.0, 1.0))\n\tarrow.add_theme_color_override(\"font_outline_color\", Color.BLACK)\n\tarrow.add_theme_constant_override(\"outline_size\", 4)\n\tfirst_run_route_marker.add_child(arrow)\n\tvar pulse := create_tween().bind_node(first_run_route_marker).set_loops()\n\tpulse.tween_property(first_run_route_marker, \"scale\", Vector2(1.12, 1.12), 0.55).set_trans(Tween.TRANS_SINE)\n\tpulse.tween_property(first_run_route_marker, \"scale\", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)\n\nfunc _create_practice_gem_station() -> void:\n"
	)
	_replace_once(
		path,
		"func _prepare_world_for_run(message: String) -> void:\n\t_set_status(message)\n\tworld.remove_meta(\"single_player_hub_active\")",
		"func _prepare_world_for_run(message: String) -> void:\n\t_set_status(message)\n\tif first_run_route_marker != null and is_instance_valid(first_run_route_marker):\n\t\tfirst_run_route_marker.queue_free()\n\tfirst_run_route_marker = null\n\tif first_run_guide_layer != null and is_instance_valid(first_run_guide_layer):\n\t\tfirst_run_guide_layer.queue_free()\n\tfirst_run_guide_layer = null\n\tworld.remove_meta(\"single_player_hub_active\")"
	)

func _patch_minewars_controller() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	_replace_once(
		path,
		"var secondary_entrance_marker: Node2D\n",
		"var secondary_entrance_marker: Node2D\nvar first_run_training_active := false\nvar muster_arrival_announced := false\n"
	)
	_replace_once(
		path,
		"\tworld.current_wave_number = stage_number\n\tworld.enemies_per_wave = int(STAGE_ENEMY_COUNTS.get(stage_number, 3))\n\tmining_timer = _mining_window_for(stage_number)\n\t_set_phase_meta(\"mining\")\n\t_ensure_surface_lanes()\n\t_create_ui()\n\t_create_primary_entrance_marker()\n\t_initialize_stage_objective()\n\t_update_ui()\n\tif hud and hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"EXPEDITION I — follow the prospect, secure a build reward, and return before the assault.\", 5.5)",
		"\tworld.current_wave_number = stage_number\n\tworld.enemies_per_wave = int(STAGE_ENEMY_COUNTS.get(stage_number, 3))\n\tfirst_run_training_active = not Global.prototype_onboarding_completed\n\tworld.set_meta(\"minewars_training_active\", first_run_training_active)\n\tworld.set_meta(\"minewars_force_return_cue\", false)\n\tworld.set_meta(\"minewars_return_seconds\", -1)\n\tmining_timer = _mining_window_for(stage_number)\n\t_set_phase_meta(\"mining\")\n\t_ensure_surface_lanes()\n\t_create_ui()\n\t_create_primary_entrance_marker()\n\t_initialize_stage_objective()\n\t_update_ui()\n\t_play_opening_banner()\n\tif hud and hud.has_method(\"show_notice\"):\n\t\tif first_run_training_active:\n\t\t\thud.show_notice(\"MINER'S TRIAL — learn to mine, carry, bank, and upgrade. The assault clock is paused.\", 5.0)\n\t\telse:\n\t\t\thud.show_notice(\"EXPEDITION I — follow the prospect, secure a build reward, and return before the assault.\", 5.5)"
	)
	_replace_once(
		path,
		"func _process_mining(delta: float) -> void:\n\tmining_timer = maxf(mining_timer - delta, 0.0)\n\t_update_stage_objective()\n\t_update_warning_stage()\n\tif mining_timer <= 0.0 and not wave_spawning:\n\t\t_start_assault()",
		"func _process_mining(delta: float) -> void:\n\tif first_run_training_active:\n\t\tmining_timer = _mining_window_for(stage_number)\n\t\twarning_stage = 0\n\t\tworld.set_meta(\"minewars_force_return_cue\", false)\n\t\tworld.set_meta(\"minewars_return_seconds\", -1)\n\t\tif Global.prototype_onboarding_completed and world.get(\"onboarding_active\") != true:\n\t\t\t_finish_first_run_training()\n\t\treturn\n\tmining_timer = maxf(mining_timer - delta, 0.0)\n\t_update_stage_objective()\n\t_update_warning_stage()\n\t_sync_return_guidance()\n\tif mining_timer <= 0.0 and not wave_spawning:\n\t\t_start_assault()"
	)
	_replace_once(
		path,
		"func _process_attack() -> void:\n\tif assault_muster_timer > 0.0:",
		"func _process_attack() -> void:\n\t_sync_return_guidance()\n\t_check_muster_arrival()\n\tif assault_muster_timer > 0.0:"
	)
	_replace_once(
		path,
		"\tassault_spawn_started = false\n\tworld.set_meta(\"wave_spawning\", true)",
		"\tassault_spawn_started = false\n\tmuster_arrival_announced = false\n\tworld.set_meta(\"wave_spawning\", true)\n\tworld.set_meta(\"minewars_force_return_cue\", true)\n\tworld.set_meta(\"minewars_return_seconds\", ceili(assault_muster_timer))"
	)
	_replace_once(
		path,
		"\tif hud and hud.has_method(\"notify_wave_started\"):\n\t\thud.notify_wave_started(stage_number == FINAL_STAGE, stage_number)",
		"\t_play_assault_warning_feedback()\n\tif hud and hud.has_method(\"notify_wave_started\"):\n\t\thud.notify_wave_started(stage_number == FINAL_STAGE, stage_number)"
	)
	_replace_once(
		path,
		"func _spawn_assault() -> void:\n\tvar is_boss := stage_number == FINAL_STAGE",
		"func _spawn_assault() -> void:\n\t_show_center_banner(\"BREACH OPEN\", \"Hold the western approach and protect the bastion.\", Color(1.0, 0.32, 0.14, 1.0), 0.9)\n\tvar is_boss := stage_number == FINAL_STAGE"
	)
	_replace_once(
		path,
		"func _complete_assault() -> void:\n\tassault_muster_timer = 0.0",
		"func _complete_assault() -> void:\n\tworld.set_meta(\"minewars_force_return_cue\", false)\n\tworld.set_meta(\"minewars_return_seconds\", -1)\n\tassault_muster_timer = 0.0"
	)
	_replace_once(
		path,
		"\tif hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"BASTION SALVAGE  +%d GEM%s — a guaranteed build choice earned.\" % [reward, \"S\" if reward != 1 else \"\"], 4.0)",
		"\tif hud.has_method(\"show_notice\"):\n\t\tif cleared_stage == 1 and Global.minewars_runs_completed == 0:\n\t\t\thud.show_notice(\"FIRST ASSAULT SURVIVED  +%d GEM — return to the bastion for your first real build choice.\" % reward, 4.8)\n\t\telse:\n\t\t\thud.show_notice(\"BASTION SALVAGE  +%d GEM%s — a guaranteed build choice earned.\" % [reward, \"S\" if reward != 1 else \"\"], 4.0)"
	)
	_replace_once(
		path,
		"func _begin_next_expedition() -> void:\n\tphase = Phase.MINING",
		"func _begin_next_expedition() -> void:\n\tworld.set_meta(\"minewars_force_return_cue\", false)\n\tworld.set_meta(\"minewars_return_seconds\", -1)\n\tphase = Phase.MINING"
	)
	_replace_once(
		path,
		"\t_update_build_label()\n\t_update_objective_label()\n\n\tif phase == Phase.ATTACK:",
		"\t_update_build_label()\n\t_update_objective_label()\n\n\tif first_run_training_active:\n\t\tstatus_label.text = \"MINER'S TRIAL  •  ASSAULT CLOCK PAUSED\\nLearn the core loop without pressure\"\n\t\tobjective_label.text = \"TRAINING • Complete the five guided steps shown on the tutorial card.\"\n\t\tvar tutorial_stage := int(world.get(\"onboarding_stage\"))\n\t\tmatch tutorial_stage:\n\t\t\t0: hint_label.text = \"Dig straight down through the center shaft.\"\n\t\t\t1: hint_label.text = \"Break the glowing cyan vein below the entrance.\"\n\t\t\t2: hint_label.text = \"Stand beside the loose crystal and press SPACE / A.\"\n\t\t\t3: hint_label.text = \"Carry the crystal back into the bastion's blue deposit zone.\"\n\t\t\t_: hint_label.text = \"Open the forge with E / Y and buy one quick stat upgrade.\"\n\t\treturn\n\n\tif phase == Phase.ATTACK:"
	)
	_replace_once(
		path,
		"func _process(delta: float) -> void:\n",
		"func _play_opening_banner() -> void:\n\tvar hero_name := str(Global.selected_hero_id)\n\tvar base_name := str(Global.base_data.get(Global.selected_base_id, Global.base_data[Global.DEFAULT_BASE_ID]).get(\"name\", \"Bastion\"))\n\tvar subtitle := \"%s • %s\\nMine • Bank • Upgrade • Defend\" % [hero_name, base_name]\n\tif first_run_training_active:\n\t\tsubtitle += \"\\nTraining first — no assault timer until the lesson is complete.\"\n\t_show_center_banner(\"MINEWARS\", subtitle, Color(0.35, 0.92, 1.0, 1.0), 1.8)\n\nfunc _finish_first_run_training() -> void:\n\tfirst_run_training_active = false\n\tworld.set_meta(\"minewars_training_active\", false)\n\tmining_timer = _mining_window_for(stage_number)\n\twarning_stage = 0\n\tif world.has_method(\"ensure_minewars_motherlodes\"):\n\t\tworld.ensure_minewars_motherlodes()\n\t_initialize_stage_objective()\n\t_show_center_banner(\"EXPEDITION CLOCK STARTED\", \"90 seconds. Follow the cyan prospect, secure the Rich Vein reward, then return to the bastion.\", Color(1.0, 0.78, 0.25, 1.0), 1.8)\n\tif hud and hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"EXPEDITION I BEGINS — the clock is live. Follow the marked seam; you do not need to mine everything.\", 5.2)\n\nfunc _sync_return_guidance() -> void:\n\tvar force_return := false\n\tvar seconds := -1\n\tif phase == Phase.MINING and warning_stage >= 2:\n\t\tforce_return = true\n\t\tseconds = ceili(mining_timer)\n\telif phase == Phase.ATTACK:\n\t\tforce_return = player.global_position.distance_to(base.global_position) > RECOVERY_BASE_DISTANCE * 1.45\n\t\tseconds = ceili(assault_muster_timer) if assault_muster_timer > 0.0 else -1\n\tworld.set_meta(\"minewars_force_return_cue\", force_return)\n\tworld.set_meta(\"minewars_return_seconds\", seconds)\n\nfunc _check_muster_arrival() -> void:\n\tif muster_arrival_announced or assault_muster_timer <= 0.0:\n\t\treturn\n\tif player.global_position.distance_to(base.global_position) > RECOVERY_BASE_DISTANCE * 1.65:\n\t\treturn\n\tmuster_arrival_announced = true\n\tworld.set_meta(\"minewars_force_return_cue\", false)\n\tif hud and hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"BASTION REACHED — face west. The breach opens in %d seconds.\" % ceili(assault_muster_timer), 3.2)\n\tvar ring := Line2D.new()\n\tring.width = 6.0\n\tring.default_color = Color(0.35, 1.0, 0.62, 0.92)\n\tvar points := PackedVector2Array()\n\tfor index in range(33):\n\t\tpoints.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * 78.0)\n\tring.points = points\n\tring.global_position = base.global_position\n\tring.z_index = 24\n\tworld.add_child(ring)\n\tring.scale = Vector2(0.45, 0.45)\n\tvar pulse := create_tween().set_parallel(true)\n\tpulse.tween_property(ring, \"scale\", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\tpulse.tween_property(ring, \"modulate:a\", 0.0, 0.8)\n\tpulse.chain().tween_callback(ring.queue_free)\n\nfunc _play_assault_warning_feedback() -> void:\n\tvar title := \"FINAL ASSAULT\" if stage_number == FINAL_STAGE else \"RETURN TO THE BASTION\"\n\tvar body := \"The Goblin War Mech reaches the western breach in %d seconds.\" % ceili(assault_muster_timer) if stage_number == FINAL_STAGE else \"The western breach opens in %d seconds. Follow the return arrow now.\" % ceili(assault_muster_timer)\n\t_show_center_banner(title, body, Color(1.0, 0.34, 0.16, 1.0), 1.3)\n\tif entrance_marker != null and is_instance_valid(entrance_marker):\n\t\tvar pulse := create_tween().set_loops(3)\n\t\tpulse.tween_property(entrance_marker, \"scale\", Vector2(1.28, 1.28), 0.16)\n\t\tpulse.tween_property(entrance_marker, \"scale\", Vector2.ONE, 0.22)\n\tvar camera := player.get_node_or_null(\"Camera2D\") as Camera2D\n\tif camera != null:\n\t\tvar rest := camera.offset\n\t\tvar shake := create_tween()\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(5, 2), 0.05)\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(-5, -2), 0.05)\n\t\tshake.tween_property(camera, \"offset\", rest, 0.09)\n\nfunc _show_center_banner(title_text: String, body_text: String, accent: Color, hold_time: float) -> void:\n\tvar layer := CanvasLayer.new()\n\tlayer.layer = 48\n\tadd_child(layer)\n\tvar panel := PanelContainer.new()\n\tpanel.custom_minimum_size = Vector2(560, 104)\n\tvar viewport_size := get_viewport().get_visible_rect().size\n\tpanel.position = Vector2((viewport_size.x - 560.0) * 0.5, viewport_size.y * 0.17)\n\tpanel.pivot_offset = Vector2(280, 52)\n\tpanel.scale = Vector2(0.78, 0.78)\n\tpanel.modulate = Color(1, 1, 1, 0)\n\tpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tvar style := StyleBoxFlat.new()\n\tstyle.bg_color = Color(0.018, 0.035, 0.05, 0.96)\n\tstyle.border_color = accent\n\tstyle.set_border_width_all(3)\n\tstyle.set_corner_radius_all(10)\n\tstyle.shadow_color = Color(0, 0, 0, 0.7)\n\tstyle.shadow_size = 8\n\tpanel.add_theme_stylebox_override(\"panel\", style)\n\tlayer.add_child(panel)\n\tvar margin := MarginContainer.new()\n\tmargin.add_theme_constant_override(\"margin_left\", 18)\n\tmargin.add_theme_constant_override(\"margin_right\", 18)\n\tmargin.add_theme_constant_override(\"margin_top\", 10)\n\tmargin.add_theme_constant_override(\"margin_bottom\", 10)\n\tpanel.add_child(margin)\n\tvar stack := VBoxContainer.new()\n\tstack.alignment = BoxContainer.ALIGNMENT_CENTER\n\tmargin.add_child(stack)\n\tvar title := Label.new()\n\ttitle.text = title_text\n\ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\ttitle.add_theme_font_size_override(\"font_size\", 24)\n\ttitle.add_theme_color_override(\"font_color\", accent)\n\tstack.add_child(title)\n\tvar body := Label.new()\n\tbody.text = body_text\n\tbody.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tbody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tbody.add_theme_font_size_override(\"font_size\", 13)\n\tbody.add_theme_color_override(\"font_color\", Color(0.92, 0.95, 0.98, 1.0))\n\tstack.add_child(body)\n\tvar tween := create_tween().set_parallel(true)\n\ttween.tween_property(panel, \"modulate\", Color.WHITE, 0.18)\n\ttween.tween_property(panel, \"scale\", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\ttween.chain().tween_interval(hold_time)\n\ttween.chain().tween_property(panel, \"modulate:a\", 0.0, 0.24)\n\ttween.chain().tween_callback(layer.queue_free)\n\nfunc _process(delta: float) -> void:\n"
	)

func _patch_hud_return_cue() -> void:
	var path := "res://hud.gd"
	var old_function := "func _update_return_cue() -> void:\n\tif not return_cue or not return_cue_arrow:\n\t\treturn\n\tvar world := get_parent()\n\tvar player := world.get_node_or_null(\"Player\") if world else null\n\tvar base := world.get_node_or_null(\"Base\") if world else null\n\tvar carry_load := int(player.get_carry_load()) if player and player.has_method(\"get_carry_load\") else 0\n\tif not player or not base or carry_load <= 0:\n\t\treturn_cue.visible = false\n\t\treturn\n\tvar to_base: Vector2 = base.global_position - player.global_position\n\tif to_base.length() < 330.0:\n\t\treturn_cue.visible = false\n\t\treturn\n\tvar direction := to_base.normalized()\n\tvar viewport_size := get_viewport().get_visible_rect().size\n\tvar center := viewport_size * 0.5\n\tvar half_extent := Vector2(max(viewport_size.x * 0.5 - 90.0, 20.0), max(viewport_size.y * 0.5 - 52.0, 20.0))\n\tvar edge_scale := 1000000.0\n\tif abs(direction.x) > 0.001:\n\t\tedge_scale = min(edge_scale, half_extent.x / abs(direction.x))\n\tif abs(direction.y) > 0.001:\n\t\tedge_scale = min(edge_scale, half_extent.y / abs(direction.y))\n\tvar cue_position := center + direction * edge_scale - return_cue.size * 0.5\n\tcue_position.x = clamp(cue_position.x, 8.0, max(viewport_size.x - return_cue.size.x - 8.0, 8.0))\n\tcue_position.y = clamp(cue_position.y, 8.0, max(viewport_size.y - return_cue.size.y - 8.0, 8.0))\n\treturn_cue.position = cue_position\n\treturn_cue_arrow.rotation = direction.angle()\n\treturn_cue.visible = true"
	var new_function := "func _update_return_cue() -> void:\n\tif not return_cue or not return_cue_arrow:\n\t\treturn\n\tvar world := get_parent()\n\tvar player := world.get_node_or_null(\"Player\") if world else null\n\tvar base := world.get_node_or_null(\"Base\") if world else null\n\tvar carry_load := int(player.get_carry_load()) if player and player.has_method(\"get_carry_load\") else 0\n\tvar force_return := bool(world.get_meta(\"minewars_force_return_cue\", false)) if world else false\n\tif not player or not base or (carry_load <= 0 and not force_return):\n\t\treturn_cue.visible = false\n\t\treturn\n\tvar to_base: Vector2 = base.global_position - player.global_position\n\tvar hide_distance := 190.0 if force_return else 330.0\n\tif to_base.length() < hide_distance:\n\t\treturn_cue.visible = false\n\t\treturn\n\tvar direction := to_base.normalized()\n\tvar viewport_size := get_viewport().get_visible_rect().size\n\tvar center := viewport_size * 0.5\n\tvar half_extent := Vector2(max(viewport_size.x * 0.5 - 90.0, 20.0), max(viewport_size.y * 0.5 - 52.0, 20.0))\n\tvar edge_scale := 1000000.0\n\tif abs(direction.x) > 0.001:\n\t\tedge_scale = min(edge_scale, half_extent.x / abs(direction.x))\n\tif abs(direction.y) > 0.001:\n\t\tedge_scale = min(edge_scale, half_extent.y / abs(direction.y))\n\tvar cue_position := center + direction * edge_scale - return_cue.size * 0.5\n\tcue_position.x = clamp(cue_position.x, 8.0, max(viewport_size.x - return_cue.size.x - 8.0, 8.0))\n\tcue_position.y = clamp(cue_position.y, 8.0, max(viewport_size.y - return_cue.size.y - 8.0, 8.0))\n\treturn_cue.position = cue_position\n\treturn_cue_arrow.rotation = direction.angle()\n\tif force_return:\n\t\tvar seconds := int(world.get_meta(\"minewars_return_seconds\", -1))\n\t\treturn_cue_label.text = \"RETURN • %ds\" % seconds if seconds >= 0 else \"RETURN TO BASE\"\n\t\treturn_cue_arrow.add_theme_color_override(\"font_color\", Color(1.0, 0.36, 0.16, 1.0))\n\t\treturn_cue_label.add_theme_color_override(\"font_color\", Color(1.0, 0.68, 0.26, 1.0))\n\t\tvar pulse := 1.0 + sin(float(Time.get_ticks_msec()) / 120.0) * 0.045\n\t\treturn_cue.scale = Vector2.ONE * pulse\n\telse:\n\t\treturn_cue_label.text = \"BANK GEMS\"\n\t\treturn_cue_arrow.add_theme_color_override(\"font_color\", Color(0.2, 0.95, 1.0, 1.0))\n\t\treturn_cue_label.add_theme_color_override(\"font_color\", Color(0.45, 1.0, 1.0, 1.0))\n\t\treturn_cue.scale = Vector2.ONE\n\treturn_cue.visible = true"
	_replace_once(path, old_function, new_function)

func _patch_first_crystal_feedback() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	_replace_once(
		path,
		"func notify_tutorial_gem_spawned(gem: Node) -> void:\n\tif not onboarding_active:\n\t\treturn\n\tif onboarding_stage <= OnboardingStage.PICK_UP_GEM:\n\t\t_set_onboarding_stage(OnboardingStage.PICK_UP_GEM)\n\tif gem and gem.has_method(\"set_tutorial_emphasis\"):\n\t\tgem.set_tutorial_emphasis(true)\n\nfunc notify_tutorial_gem_picked(_gem: Node) -> void:",
		"func notify_tutorial_gem_spawned(gem: Node) -> void:\n\tif not onboarding_active:\n\t\treturn\n\tif onboarding_stage <= OnboardingStage.PICK_UP_GEM:\n\t\t_set_onboarding_stage(OnboardingStage.PICK_UP_GEM)\n\tif gem and gem.has_method(\"set_tutorial_emphasis\"):\n\t\tgem.set_tutorial_emphasis(true)\n\t_play_first_crystal_discovery(gem)\n\nfunc _play_first_crystal_discovery(gem: Node) -> void:\n\tif gem == null or bool(get_meta(\"first_crystal_discovery_played\", false)):\n\t\treturn\n\tset_meta(\"first_crystal_discovery_played\", true)\n\tvar position := (gem as Node2D).global_position if gem is Node2D else Vector2.ZERO\n\t_spawn_resource_burst(position, Color(0.24, 1.0, 0.95, 1.0), \"FirstCrystalDiscovery\", 34)\n\t_spawn_feedback_label(position + Vector2(0, -36), \"FIRST CRYSTAL!\", Color(0.52, 1.0, 1.0), 1.25)\n\tvar hud := get_node_or_null(\"HUD\")\n\tif hud and hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"CRYSTAL DISCOVERED — step beside it and press SPACE / A to attach it to your hero.\", 3.6)\n\tvar player := get_node_or_null(\"Player\")\n\tvar camera := player.get_node_or_null(\"Camera2D\") as Camera2D if player else null\n\tif camera != null:\n\t\tvar rest := camera.offset\n\t\tvar shake := create_tween()\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(4, -3), 0.045)\n\t\tshake.tween_property(camera, \"offset\", rest + Vector2(-3, 2), 0.045)\n\t\tshake.tween_property(camera, \"offset\", rest, 0.07)\n\nfunc notify_tutorial_gem_picked(_gem: Node) -> void:"
	)

func _replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Patch target missing in %s: %s" % [path, old_text.left(120)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
