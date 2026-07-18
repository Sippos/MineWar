extends Node

func _patch(path: String, replacements: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(path)
	for old_value in replacements:
		var old_text := str(old_value)
		var new_text := str(replacements[old_value])
		if not source.contains(old_text):
			push_error("Missing patch target in %s: %s" % [path, old_text.left(80)])
			continue
		source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _ready() -> void:
	_patch("res://match_flow.gd", {
		"\tGlobal.award_run_legacy_ore(wave_reached, victory)\n\tif victory:\n\t\tGlobal.mark_first_level_beaten()": "\tGlobal.award_run_legacy_ore(wave_reached, victory)\n\tGlobal.record_minewars_result(victory)",
		"\tvar workshop := _make_result_button(\"Workshop\", Callable(self, \"_return_to_preparation\"), button_width)": "\tvar workshop_label := \"Stronghold\" if Global.is_legacy_workshop_unlocked() else \"Return Home\"\n\tvar workshop := _make_result_button(workshop_label, Callable(self, \"_return_to_preparation\"), button_width)",
		"\tvar reward_banner := _build_legacy_reward_banner(compact)\n\tcontent.add_child(reward_banner)": "\tvar reward_banner := _build_legacy_reward_banner(compact)\n\tcontent.add_child(reward_banner)\n\tvar unlock_banner := _build_unlock_reward_banner(compact)\n\tif unlock_banner != null:\n\t\tcontent.add_child(unlock_banner)",
		"func _build_legacy_reward_banner(compact: bool) -> PanelContainer:": "func _build_unlock_reward_banner(compact: bool) -> PanelContainer:\n\tif Global.last_unlock_rewards.is_empty():\n\t\treturn null\n\tvar reward: Dictionary = Global.last_unlock_rewards.back()\n\tvar banner := PanelContainer.new()\n\tbanner.name = \"MilestoneReward\"\n\tbanner.custom_minimum_size = Vector2(0, 48 if compact else 52)\n\tbanner.add_theme_stylebox_override(\"panel\", _make_flat_panel_style(Color(0.035, 0.09, 0.12, 0.96), Color(0.28, 0.82, 1.0, 0.98)))\n\tvar label := Label.new()\n\tlabel.text = \"STRONGHOLD REWARD  •  %s\" % str(reward.get(\"title\", \"NEW POWER AWAKENED\"))\n\tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER\n\tlabel.add_theme_font_size_override(\"font_size\", 14 if compact else 16)\n\tlabel.add_theme_color_override(\"font_color\", Color(0.72, 0.94, 1.0, 1.0))\n\tbanner.add_child(label)\n\treturn banner\n\nfunc _build_legacy_reward_banner(compact: bool) -> PanelContainer:"
	})
	_patch("res://scripts/ui/menus/loadout_selection_menu.gd", {
		"\t\tif Global.first_level_beaten\n\t\telse \"FIRST EXPEDITION  •  Dwarf Bastion is your only awakened fortress. Win MineWars once to unlock the others.\"": "\t\tif Global.unlocked_bases.size() > 1\n\t\telse \"The Dwarf Bastion is your only awakened fortress. Victories awaken new faction homes one at a time.\"",
		"func _base_unlocked(base_id: String) -> bool:\n\treturn base_id == \"default_base\" or bool(Global.first_level_beaten)": "func _base_unlocked(base_id: String) -> bool:\n\treturn Global.is_base_unlocked(base_id)"
	})
	_patch("res://scripts/systems/preparation/in_world_hero_selector.gd", {
		"\t\tcard_action.text = \"LOCKED  •  WIN MINEWARS ONCE\"": "\t\tcard_action.text = \"DORMANT  •  COMPLETE MORE MINEWARS VICTORIES\"",
		"\t_set_hub_status(\"%s is dormant. Win MineWars once to awaken every remaining hero.\" % hero_name)": "\t_set_hub_status(\"%s is dormant. Each MineWars victory awakens one new hero and fortress.\" % hero_name)",
		"\tcard_action.text = \"%s IS DORMANT  •  WIN MINEWARS ONCE\" % hero_name.to_upper()": "\tcard_action.text = \"%s IS DORMANT  •  EARN ANOTHER VICTORY\" % hero_name.to_upper()"
	})
	_patch("res://scenes/ui/overlays/single_player_hub_hud.tscn", {
		"text = \"Choose a hero • Choose a fortress • Enter a tunnel\"": "text = \"Prepare your bastion • Descend • Return stronger\""
	})
	print("MINEWARS_PROGRESSION_LOOP_FINALIZED")
	get_tree().quit(0)
