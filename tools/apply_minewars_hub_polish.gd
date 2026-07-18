extends Node

var failures := 0

func _ready() -> void:
	_patch_single_player_controller()
	_patch_hero_selector()
	_patch_loadout_menu()
	_patch_base_prompt()
	if failures == 0:
		print("MINEWARS_HUB_POLISH_APPLIED")
		get_tree().quit(0)
	else:
		push_error("MINEWARS_HUB_POLISH_FAILED: %d replacements missing" % failures)
		get_tree().quit(1)

func _replace_required(source: String, old_text: String, new_text: String, label: String) -> String:
	if not source.contains(old_text):
		failures += 1
		push_error("Missing hub patch target: " + label)
		return source
	return source.replace(old_text, new_text)

func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _patch_single_player_controller() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	source = _replace_required(source,
		"\tif Global.first_level_beaten:\n\t\tfor hero_name in Global.hero_data.keys():\n\t\t\tGlobal.unlock_hero(str(hero_name))\n\n\tGlobal.apply_selected_loadout()",
		"\tvar pending_rewards: Array = Global.consume_pending_unlock_rewards()\n\tvar newly_unlocked_heroes: Array = []\n\tfor reward_value in pending_rewards:\n\t\tvar reward: Dictionary = reward_value\n\t\tvar hero_name := str(reward.get(\"hero\", \"\"))\n\t\tif not hero_name.is_empty():\n\t\t\tnewly_unlocked_heroes.append(hero_name)\n\tworld.set_meta(\"newly_unlocked_heroes\", newly_unlocked_heroes)\n\tworld.set_meta(\"stronghold_pending_rewards\", pending_rewards)\n\n\tGlobal.apply_selected_loadout()",
		"consume pending rewards")
	source = _replace_required(source,
		"\t_configure_progression_signs()\n\t_set_initial_status()",
		"\t_configure_progression_signs()\n\t_set_initial_status()\n\tif not pending_rewards.is_empty():\n\t\tcall_deferred(\"_play_unlock_ceremony\", pending_rewards)",
		"trigger unlock ceremony")
	source = _replace_required(source,
		"\tif mine_wars:\n\t\tmine_wars.text = \"MINEWARS\\nBOTTOM TUNNEL\"\n\t\tmine_wars.modulate = Color.WHITE\n\tif _advanced_modes_unlocked():\n\t\tif line_wars:\n\t\t\tline_wars.text = \"LINEWARS\\nTOP TUNNEL\"\n\t\t\tline_wars.modulate = Color.WHITE\n\t\tif adventure:\n\t\t\tadventure.text = \"ADVENTURE\\nRIGHT TUNNEL\"\n\t\t\tadventure.modulate = Color.WHITE\n\telse:\n\t\tif line_wars:\n\t\t\tline_wars.text = \"LINEWARS\\nLOCKED\"\n\t\t\tline_wars.modulate = Color(0.42, 0.44, 0.48, 0.9)\n\t\tif adventure:\n\t\t\tadventure.text = \"ADVENTURE\\nLOCKED\"\n\t\t\tadventure.modulate = Color(0.42, 0.44, 0.48, 0.9)",
		"\tif mine_wars:\n\t\tmine_wars.text = \"DESCEND TO MINEWARS\"\n\t\tmine_wars.modulate = Color.WHITE\n\tif line_wars:\n\t\tline_wars.visible = _advanced_modes_unlocked()\n\t\tif line_wars.visible:\n\t\t\tline_wars.text = \"LINEWARS\\nTOP TUNNEL\"\n\t\t\tline_wars.modulate = Color.WHITE\n\tif adventure:\n\t\tadventure.visible = _advanced_modes_unlocked()\n\t\tif adventure.visible:\n\t\t\tadventure.text = \"ADVENTURE\\nRIGHT TUNNEL\"\n\t\t\tadventure.modulate = Color.WHITE",
		"hide unrevealed routes")
	source = _replace_required(source,
		"func _set_initial_status() -> void:\n\tif _advanced_modes_unlocked():\n\t\t_set_status(\"Stand on a hero rune to switch. Use the central base to choose a fortress. Enter a wall tunnel to play.\")\n\telse:\n\t\t_set_status(\"FIRST EXPEDITION  •  Stand on the Dwarf rune, inspect the central base, then enter MineWars below.\")",
		"func _set_initial_status() -> void:\n\tif Global.minewars_runs_completed == 0:\n\t\t_set_status(\"The Dwarf Bastion stands alone. Descend through the lower shaft when you are ready.\")\n\telif _advanced_modes_unlocked():\n\t\t_set_status(\"The stronghold is growing. Choose an awakened hero or fortress, then descend for another expedition.\")\n\telse:\n\t\t_set_status(\"Legacy Ore has strengthened the bastion. Descend again and push farther.\")",
		"initial stronghold status")

	var ceremony_insert := "func _play_unlock_ceremony(rewards: Array) -> void:\n\tif rewards.is_empty() or hub_hud == null or not is_instance_valid(hub_hud):\n\t\treturn\n\tfor reward_value in rewards:\n\t\tvar reward: Dictionary = reward_value\n\t\tvar banner := PanelContainer.new()\n\t\tbanner.name = \"StrongholdUnlockBanner\"\n\t\tbanner.process_mode = Node.PROCESS_MODE_ALWAYS\n\t\tbanner.position = Vector2(326, 82)\n\t\tbanner.custom_minimum_size = Vector2(500, 104)\n\t\tbanner.modulate = Color(1, 1, 1, 0)\n\t\thub_hud.add_child(banner)\n\t\tvar margin := MarginContainer.new()\n\t\tmargin.add_theme_constant_override(\"margin_left\", 18)\n\t\tmargin.add_theme_constant_override(\"margin_right\", 18)\n\t\tmargin.add_theme_constant_override(\"margin_top\", 12)\n\t\tmargin.add_theme_constant_override(\"margin_bottom\", 12)\n\t\tbanner.add_child(margin)\n\t\tvar stack := VBoxContainer.new()\n\t\tstack.alignment = BoxContainer.ALIGNMENT_CENTER\n\t\tmargin.add_child(stack)\n\t\tvar title := Label.new()\n\t\ttitle.text = str(reward.get(\"title\", \"STRONGHOLD EXPANDED\"))\n\t\ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\t\ttitle.add_theme_font_size_override(\"font_size\", 24)\n\t\ttitle.add_theme_color_override(\"font_color\", Color(1.0, 0.82, 0.3, 1.0))\n\t\tstack.add_child(title)\n\t\tvar description := Label.new()\n\t\tdescription.text = str(reward.get(\"description\", \"A new power has joined the stronghold.\"))\n\t\tdescription.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\t\tdescription.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\t\tdescription.add_theme_font_size_override(\"font_size\", 14)\n\t\tstack.add_child(description)\n\t\t_set_status(description.text)\n\t\tvar reveal := create_tween().set_parallel(true)\n\t\treveal.tween_property(banner, \"modulate\", Color.WHITE, 0.3)\n\t\treveal.tween_property(banner, \"position:y\", 98.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\t\tawait reveal.finished\n\t\tawait get_tree().create_timer(2.2).timeout\n\t\tvar hide := create_tween()\n\t\thide.tween_property(banner, \"modulate:a\", 0.0, 0.24)\n\t\tawait hide.finished\n\t\tbanner.queue_free()\n\tworld.remove_meta(\"stronghold_pending_rewards\")\n\n"
	var ceremony_at := source.find("func _show_locked_message")
	if ceremony_at < 0:
		failures += 1
		push_error("Missing hub patch target: ceremony insertion")
	else:
		source = source.substr(0, ceremony_at) + ceremony_insert + source.substr(ceremony_at)
	if failures == 0:
		_write(path, source)

func _patch_hero_selector() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var source := FileAccess.get_file_as_string(path)
	source = _replace_required(source,
		"\t_refresh_shrines()\n\tget_tree().root.size_changed.connect(_update_card_position)",
		"\t_refresh_shrines()\n\tcall_deferred(\"_animate_newly_unlocked_shrines\")\n\tget_tree().root.size_changed.connect(_update_card_position)",
		"animate new shrines")
	source = _replace_required(source,
		"\tfor hero_name in HERO_ORDER:\n\t\tvar shrine: Node2D = hero_nodes[hero_name][\"root\"]",
		"\tfor hero_name in HERO_ORDER:\n\t\tif not hero_nodes.has(hero_name):\n\t\t\tcontinue\n\t\tvar shrine: Node2D = hero_nodes[hero_name][\"root\"]",
		"safe process loop")
	source = _replace_required(source,
		"\tfor hero_name in HERO_ORDER:\n\t\tvar root := Node2D.new()",
		"\tfor hero_name in HERO_ORDER:\n\t\tif not _hero_unlocked(hero_name):\n\t\t\tcontinue\n\t\tvar root := Node2D.new()",
		"only build awakened heroes")
	source = _replace_required(source,
		"func _refresh_shrines() -> void:\n\tfor hero_name in HERO_ORDER:\n\t\tvar data: Dictionary = hero_nodes[hero_name]",
		"func _refresh_shrines() -> void:\n\tfor hero_name in HERO_ORDER:\n\t\tif not hero_nodes.has(hero_name):\n\t\t\tcontinue\n\t\tvar data: Dictionary = hero_nodes[hero_name]",
		"safe refresh loop")
	source = _replace_required(source,
		"func _hero_unlocked(hero_name: String) -> bool:\n\treturn hero_name == \"Dwarf\" or bool(Global.first_level_beaten)",
		"func _hero_unlocked(hero_name: String) -> bool:\n\treturn Global.is_hero_unlocked(hero_name)",
		"use milestone hero unlocks")
	var animation_insert := "func _animate_newly_unlocked_shrines() -> void:\n\tif world == null:\n\t\treturn\n\tvar newly_unlocked: Array = world.get_meta(\"newly_unlocked_heroes\", [])\n\tfor hero_value in newly_unlocked:\n\t\tvar hero_name := str(hero_value)\n\t\tif not hero_nodes.has(hero_name):\n\t\t\tcontinue\n\t\tvar root: Node2D = hero_nodes[hero_name][\"root\"]\n\t\troot.modulate = Color(1, 1, 1, 0)\n\t\troot.scale = Vector2(0.18, 0.18)\n\t\tvar tween := create_tween().set_parallel(true)\n\t\ttween.tween_property(root, \"modulate\", Color.WHITE, 0.5)\n\t\ttween.tween_property(root, \"scale\", Vector2.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n\t\tawait tween.finished\n\tworld.remove_meta(\"newly_unlocked_heroes\")\n\n"
	var animation_at := source.find("func _card_style")
	if animation_at < 0:
		failures += 1
		push_error("Missing hub patch target: shrine animation insertion")
	else:
		source = source.substr(0, animation_at) + animation_insert + source.substr(animation_at)
	if failures == 0:
		_write(path, source)

func _patch_loadout_menu() -> void:
	var path := "res://scripts/ui/menus/loadout_selection_menu.gd"
	var source := FileAccess.get_file_as_string(path)
	source = _replace_required(source,
		"\tprogression_label.text = (\n\t\t\"Choose any unlocked fortress. The hero remains unchanged until you walk to another hero pedestal.\"\n\t\tif Global.first_level_beaten\n\t\telse \"FIRST EXPEDITION  •  Dwarf Bastion is your only awakened fortress. Win MineWars once to unlock the others.\"\n\t)",
		"\tprogression_label.text = (\n\t\t\"Choose one of the fortresses that has joined your stronghold.\"\n\t\tif Global.unlocked_bases.size() > 1\n\t\telse \"The Dwarf Bastion is prepared for the expedition.\"\n\t)",
		"remove unlock count hint")
	source = _replace_required(source,
		"\t\tbutton.text = short_name if unlocked else \"%s\\nLOCKED\" % short_name\n\t\tbutton.disabled = not unlocked\n\t\tbutton.modulate = Color.WHITE if unlocked else Color(0.42, 0.44, 0.48, 0.75)",
		"\t\tbutton.visible = unlocked\n\t\tbutton.text = short_name\n\t\tbutton.disabled = not unlocked\n\t\tbutton.modulate = Color.WHITE",
		"hide locked base buttons")
	source = _replace_required(source,
		"func _base_unlocked(base_id: String) -> bool:\n\treturn base_id == \"default_base\" or bool(Global.first_level_beaten)",
		"func _base_unlocked(base_id: String) -> bool:\n\treturn Global.is_base_unlocked(base_id)",
		"use milestone base unlocks")
	if failures == 0:
		_write(path, source)

func _patch_base_prompt() -> void:
	var path := "res://base.gd"
	var source := FileAccess.get_file_as_string(path)
	source = _replace_required(source,
		"const HUB_PROMPT_TEXT := \"E / Y  •  CHOOSE BASE\"",
		"const HUB_PROMPT_TEXT := \"E / Y  •  INSPECT BASTION\"",
		"initial base prompt")
	source = _replace_required(source,
		"\tif _is_single_player_hub() and player_in_zone:\n\t\tprompt.text = HUB_PROMPT_TEXT\n\t\t_set_prompt_visible(true)",
		"\tif _is_single_player_hub() and player_in_zone:\n\t\tprompt.text = \"E / Y  •  MANAGE STRONGHOLD\" if Global.is_legacy_workshop_unlocked() or Global.unlocked_bases.size() > 1 else HUB_PROMPT_TEXT\n\t\t_set_prompt_visible(true)",
		"dynamic stronghold prompt")
	if failures == 0:
		_write(path, source)
