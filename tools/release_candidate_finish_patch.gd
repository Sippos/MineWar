extends Node

var failures: Array[String] = []
var changed_files: Array[String] = []

func _ready() -> void:
	_patch_project_name()
	_patch_main_menu()
	_patch_stronghold_first_run_guide()
	_patch_minewars_training_gate()
	_patch_complete_run_test()
	if failures.is_empty():
		print("RELEASE_CANDIDATE_FINISH_PATCH_OK changed=", changed_files)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_project_name() -> void:
	_replace_once("res://project.godot", 'config/name="Mining"', 'config/name="MineWars"')

func _patch_main_menu() -> void:
	var path := "res://scripts/ui/menus/main/menu.gd"
	_replace_once(
		path,
		"func _ready() -> void:\n\ttheme = MENU_THEME\n",
		"func _ready() -> void:\n\ttheme = MENU_THEME\n\t_configure_release_menu()\n"
	)
	_replace_once(
		path,
		"func _configure_focus_navigation() -> void:\n\tvar buttons: Array[Button] = [\n\t\tsingle_player_button,\n\t\tlocal_multiplayer_button,\n\t\tonline_multiplayer_button,\n\t\tcontrols_button,\n\t\tsettings_button,\n\t]\n\tfor index in buttons.size():\n\t\tif index > 0:\n\t\t\tbuttons[index].focus_neighbor_top = buttons[index - 1].get_path()\n\t\tif index < buttons.size() - 1:\n\t\t\tbuttons[index].focus_neighbor_bottom = buttons[index + 1].get_path()\n\tsettings_button.focus_neighbor_bottom = lexicon_button.get_path()\n\tlexicon_button.focus_neighbor_top = settings_button.get_path()\n",
		"func _configure_release_menu() -> void:\n\t$Label.text = \"MINEWARS\"\n\tsingle_player_button.text = \"START EXPEDITION\"\n\tsingle_player_button.tooltip_text = \"Begin the four-stage MineWars run with your selected hero and bastion.\"\n\tlocal_multiplayer_button.text = \"STRONGHOLD & LOADOUT\"\n\tlocal_multiplayer_button.tooltip_text = \"Visit the stronghold, change hero or base, and inspect permanent progression.\"\n\tonline_multiplayer_button.text = \"ADVANCED MODES\" if Global.first_level_beaten else \"ADVANCED MODES — WIN ONCE\"\n\tonline_multiplayer_button.tooltip_text = \"LineWars and Adventure awaken after the first MineWars victory.\"\n\tonline_multiplayer_button.disabled = not Global.first_level_beaten\n\tvar tagline := Label.new()\n\ttagline.name = \"ReleaseTagline\"\n\ttagline.text = \"MINE • BUILD • RETURN • DEFEND\"\n\ttagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\ttagline.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\ttagline.add_theme_font_size_override(\"font_size\", 14)\n\ttagline.add_theme_color_override(\"font_color\", Color(0.72, 0.9, 1.0, 0.94))\n\ttagline.add_theme_color_override(\"font_outline_color\", Color(0.01, 0.02, 0.04, 0.96))\n\ttagline.add_theme_constant_override(\"outline_size\", 3)\n\tadd_child(tagline)\n\nfunc _configure_focus_navigation() -> void:\n\tvar buttons: Array[Button] = [single_player_button, local_multiplayer_button]\n\tif not online_multiplayer_button.disabled:\n\t\tbuttons.append(online_multiplayer_button)\n\tbuttons.append(controls_button)\n\tbuttons.append(settings_button)\n\tfor index in buttons.size():\n\t\tbuttons[index].focus_neighbor_top = buttons[index - 1].get_path() if index > 0 else NodePath()\n\t\tbuttons[index].focus_neighbor_bottom = buttons[index + 1].get_path() if index < buttons.size() - 1 else lexicon_button.get_path()\n\tlexicon_button.focus_neighbor_top = settings_button.get_path()\n"
	)
	_replace_once(
		path,
		"\t$Label.add_theme_constant_override(\"outline_size\", 4)\n\n\tvar panel := $MenuPanel as Sprite2D\n",
		"\t$Label.add_theme_constant_override(\"outline_size\", 4)\n\tvar tagline := get_node_or_null(\"ReleaseTagline\") as Label\n\tif tagline:\n\t\ttagline.offset_left = center_x - title_width * 0.5\n\t\ttagline.offset_top = $Label.offset_bottom - 2.0\n\t\ttagline.offset_right = center_x + title_width * 0.5\n\t\ttagline.offset_bottom = tagline.offset_top + 24.0\n\n\tvar panel := $MenuPanel as Sprite2D\n"
	)
	_replace_once(
		path,
		"func _on_single_player_pressed() -> void:\n\t# Single Player always enters the shared overworld. The player chooses the\n\t# actual destination physically from there.\n\tGameMode.set_mode(GameMode.Mode.SIEGE)\n\tGlobal.apply_selected_loadout()\n\tget_tree().change_scene_to_file(\"res://scenes/world/preparation/preparation_hub.tscn\")\n",
		"func _on_single_player_pressed() -> void:\n\tGameMode.set_mode(GameMode.Mode.SIEGE)\n\tGlobal.apply_selected_loadout()\n\tget_tree().change_scene_to_file(\"res://scenes/world/mine/level.tscn\")\n"
	)
	_replace_once(
		path,
		"func _on_local_multiplayer_pressed() -> void:\n\t_open_multiplayer_menu(false)\n\nfunc _on_online_multiplayer_pressed() -> void:\n\t_open_multiplayer_menu(true)\n",
		"func _on_local_multiplayer_pressed() -> void:\n\tGameMode.set_mode(GameMode.Mode.HUB)\n\tGlobal.apply_selected_loadout()\n\tget_tree().change_scene_to_file(\"res://scenes/world/preparation/preparation_hub.tscn\")\n\nfunc _on_online_multiplayer_pressed() -> void:\n\tif not Global.first_level_beaten:\n\t\treturn\n\tGameMode.set_mode(GameMode.Mode.HUB)\n\tGlobal.apply_selected_loadout()\n\tget_tree().change_scene_to_file(\"res://scenes/world/preparation/preparation_hub.tscn\")\n"
	)

func _patch_stronghold_first_run_guide() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	_replace_once(
		path,
		"\tif Global.minewars_runs_completed == 0 and not Global.prototype_onboarding_completed:\n\t\t_create_first_run_stronghold_cue()\n",
		"\tif Global.minewars_runs_completed == 0 and not Global.prototype_onboarding_completed:\n\t\t_create_first_run_stronghold_cue()\n\t\t_create_first_run_guide_panel()\n"
	)
	_replace_once(
		path,
		"func _create_practice_gem_station() -> void:\n",
		"func _create_first_run_guide_panel() -> void:\n\tif first_run_guide_layer != null or hub_hud == null:\n\t\treturn\n\tfirst_run_guide_layer = CanvasLayer.new()\n\tfirst_run_guide_layer.name = \"FirstRunStrongholdGuide\"\n\tfirst_run_guide_layer.layer = 44\n\tadd_child(first_run_guide_layer)\n\tvar panel := PanelContainer.new()\n\tpanel.set_anchors_preset(Control.PRESET_TOP_WIDE)\n\tpanel.offset_left = 170.0\n\tpanel.offset_top = 82.0\n\tpanel.offset_right = -170.0\n\tpanel.offset_bottom = 164.0\n\tpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tvar style := StyleBoxFlat.new()\n\tstyle.bg_color = Color(0.015, 0.045, 0.065, 0.96)\n\tstyle.border_color = Color(0.3, 0.88, 1.0, 0.94)\n\tstyle.set_border_width_all(2)\n\tstyle.set_corner_radius_all(10)\n\tstyle.shadow_color = Color(0, 0, 0, 0.62)\n\tstyle.shadow_size = 7\n\tpanel.add_theme_stylebox_override(\"panel\", style)\n\tfirst_run_guide_layer.add_child(panel)\n\tvar label := Label.new()\n\tlabel.text = \"FIRST EXPEDITION  •  Walk DOWN into MineWars\\nThe assault clock stays paused until you learn to mine, carry, bank, and upgrade.\"\n\tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER\n\tlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tlabel.add_theme_font_size_override(\"font_size\", 15)\n\tlabel.add_theme_color_override(\"font_color\", Color(0.86, 0.96, 1.0, 1.0))\n\tpanel.add_child(label)\n\tpanel.modulate = Color(1, 1, 1, 0)\n\tpanel.scale = Vector2(0.92, 0.92)\n\tpanel.pivot_offset = Vector2(400, 40)\n\tvar reveal := create_tween().set_parallel(true)\n\treveal.tween_property(panel, \"modulate\", Color.WHITE, 0.28)\n\treveal.tween_property(panel, \"scale\", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\nfunc _create_practice_gem_station() -> void:\n"
	)
	_replace_once(
		path,
		"\tif first_run_route_marker != null and is_instance_valid(first_run_route_marker):\n\t\tfirst_run_route_marker.queue_free()\n\tfirst_run_route_marker = null\n\tworld.remove_meta(\"single_player_hub_active\")\n",
		"\tif first_run_route_marker != null and is_instance_valid(first_run_route_marker):\n\t\tfirst_run_route_marker.queue_free()\n\tfirst_run_route_marker = null\n\tif first_run_guide_layer != null and is_instance_valid(first_run_guide_layer):\n\t\tfirst_run_guide_layer.queue_free()\n\tfirst_run_guide_layer = null\n\tworld.remove_meta(\"single_player_hub_active\")\n"
	)

func _patch_minewars_training_gate() -> void:
	var path := "res://scripts/systems/world_generation/siege_mode_controller.gd"
	_replace_once(
		path,
		"var first_run_training_active := false\nvar muster_arrival_announced := false\n",
		"var first_run_training_active := false\nvar first_expedition_run := false\nvar muster_arrival_announced := false\n"
	)
	_replace_once(
		path,
		"\tworld.current_wave_number = stage_number\n\tworld.enemies_per_wave = int(STAGE_ENEMY_COUNTS.get(stage_number, 3))\n\tmining_timer = _mining_window_for(stage_number)\n",
		"\tworld.current_wave_number = stage_number\n\tworld.enemies_per_wave = int(STAGE_ENEMY_COUNTS.get(stage_number, 3))\n\tfirst_expedition_run = Global.minewars_runs_completed == 0\n\tfirst_run_training_active = not Global.prototype_onboarding_completed\n\tworld.set_meta(\"minewars_first_expedition\", first_expedition_run)\n\tworld.set_meta(\"minewars_training_active\", first_run_training_active)\n\tmining_timer = _mining_window_for(stage_number)\n"
	)
	_replace_once(
		path,
		"\tvar sound_fx := get_node_or_null(\"/root/SoundFX\")\n\tif sound_fx and sound_fx.has_method(\"play_mine_awaken\"):\n\t\tsound_fx.play_mine_awaken()\n\nfunc _spawn_base_signal",
		"\tvar sound_fx := get_node_or_null(\"/root/SoundFX\")\n\tif sound_fx and sound_fx.has_method(\"play_mine_awaken\"):\n\t\tsound_fx.play_mine_awaken()\n\tif hud and hud.has_method(\"show_notice\"):\n\t\tif first_run_training_active:\n\t\t\thud.show_notice(\"MINER'S TRIAL — the assault clock is paused. Complete the five guided steps first.\", 5.2)\n\t\telse:\n\t\t\thud.show_notice(\"EXPEDITION I — follow the marked Rich Vein, then return before the assault.\", 5.0)\n\nfunc _spawn_base_signal"
	)
	_replace_once(
		path,
		"func _process_mining(delta: float) -> void:\n\tmining_timer = maxf(mining_timer - delta, 0.0)\n\t_update_stage_objective()\n\t_update_warning_stage()\n\t_sync_return_guidance()\n\tif mining_timer <= 0.0 and not wave_spawning:\n\t\t_start_assault()\n",
		"func _process_mining(delta: float) -> void:\n\tif first_run_training_active:\n\t\tmining_timer = _mining_window_for(stage_number)\n\t\twarning_stage = 0\n\t\tworld.set_meta(\"minewars_force_return_cue\", false)\n\t\tworld.set_meta(\"minewars_return_seconds\", -1)\n\t\tif Global.prototype_onboarding_completed and world.get(\"onboarding_active\") != true:\n\t\t\t_finish_first_run_training()\n\t\treturn\n\tmining_timer = maxf(mining_timer - delta, 0.0)\n\t_update_stage_objective()\n\t_update_warning_stage()\n\t_sync_return_guidance()\n\tif mining_timer <= 0.0 and not wave_spawning:\n\t\t_start_assault()\n"
	)
	_replace_once(
		path,
		"func _process(delta: float) -> void:\n",
		"func _finish_first_run_training() -> void:\n\tfirst_run_training_active = false\n\tworld.set_meta(\"minewars_training_active\", false)\n\tmining_timer = _mining_window_for(stage_number)\n\twarning_stage = 0\n\t_initialize_stage_objective()\n\t_spawn_base_signal(Color(1.0, 0.78, 0.24, 0.92), 2, 68.0)\n\tif hud and hud.has_method(\"show_notice\"):\n\t\thud.show_notice(\"EXPEDITION CLOCK STARTED — 90 seconds. Follow the cyan Rich Vein marker, then return to defend.\", 5.4)\n\nfunc _process(delta: float) -> void:\n"
	)
	_replace_once(
		path,
		"\t_update_build_label()\n\t_update_objective_label()\n\n\tif phase == Phase.ATTACK:\n",
		"\t_update_build_label()\n\t_update_objective_label()\n\n\tif first_run_training_active:\n\t\thint_label.visible = true\n\t\tstatus_label.text = \"MINER'S TRIAL  •  CLOCK PAUSED\\nLearn the core loop without pressure\"\n\t\tobjective_label.text = \"TRAINING  •  Complete the five guided HUD steps\"\n\t\tmatch int(world.get(\"onboarding_stage\")):\n\t\t\t0: hint_label.text = \"Dig straight down through the center shaft.\"\n\t\t\t1: hint_label.text = \"Break the glowing cyan crystal seam.\"\n\t\t\t2: hint_label.text = \"Stand beside the crystal and press SPACE / A.\"\n\t\t\t3: hint_label.text = \"Carry it back into the bastion deposit zone.\"\n\t\t\t_: hint_label.text = \"Open the forge with E / Y and buy one stat upgrade.\"\n\t\treturn\n\thint_label.visible = false\n\n\tif phase == Phase.ATTACK:\n"
	)

func _patch_complete_run_test() -> void:
	var path := "res://tests/minewars_complete_run_runner.gd"
	_replace_once(
		path,
		"\t_test_initial_journey_state()\n\t_test_build_identities()\n\n\tvar initial_gems := int(hud.get(\"total_gems\"))\n",
		"\t_test_initial_journey_state()\n\t_test_build_identities()\n\tif bool(controller.get(\"first_run_training_active\")):\n\t\tlevel.set(\"onboarding_active\", false)\n\t\tGlobal.complete_prototype_onboarding()\n\t\tawait _wait_frames(4)\n\t\t_expect(not bool(controller.get(\"first_run_training_active\")), \"Completing the tutorial should start the first expedition clock\")\n\n\tvar initial_gems := int(hud.get(\"total_gems\"))\n"
	)

func _replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Patch target missing in %s: %s" % [path, old_text.left(120).replace("\n", "\\n")])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
	if not changed_files.has(path):
		changed_files.append(path)
