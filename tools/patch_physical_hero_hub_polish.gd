extends Node

func _ready() -> void:
	_patch_file("res://scripts/systems/preparation/in_world_hero_selector.gd", {
		"const CARD_SIZE := Vector2(334, 356)": "const CARD_SIZE := Vector2(310, 330)",
		"const CARD_TOP_SAFE := 92.0": "const CARD_TOP_SAFE := 86.0",
		"margin.add_theme_constant_override(\"margin_left\", 14)": "margin.add_theme_constant_override(\"margin_left\", 12)",
		"margin.add_theme_constant_override(\"margin_top\", 12)": "margin.add_theme_constant_override(\"margin_top\", 10)",
		"margin.add_theme_constant_override(\"margin_right\", 14)": "margin.add_theme_constant_override(\"margin_right\", 12)",
		"margin.add_theme_constant_override(\"margin_bottom\", 12)": "margin.add_theme_constant_override(\"margin_bottom\", 10)",
		"header.custom_minimum_size = Vector2(0, 70)": "header.custom_minimum_size = Vector2(0, 62)",
		"portrait_frame.custom_minimum_size = Vector2(70, 70)": "portrait_frame.custom_minimum_size = Vector2(62, 62)",
		"card_title.add_theme_font_size_override(\"font_size\", 22)": "card_title.add_theme_font_size_override(\"font_size\", 20)",
		"card_description.custom_minimum_size = Vector2(0, 40)": "card_description.custom_minimum_size = Vector2(0, 34)",
		"card_action_panel.custom_minimum_size = Vector2(0, 36)": "card_action_panel.custom_minimum_size = Vector2(0, 34)",
		"row.custom_minimum_size = Vector2(0, 42)": "row.custom_minimum_size = Vector2(0, 36)",
		"icon_frame.custom_minimum_size = Vector2(38, 38)": "icon_frame.custom_minimum_size = Vector2(32, 32)",
		"title.add_theme_font_size_override(\"font_size\", 12)": "title.add_theme_font_size_override(\"font_size\", 11)",
		"description.add_theme_font_size_override(\"font_size\", 10)": "description.add_theme_font_size_override(\"font_size\", 9)"
	})
	_patch_file("res://base.gd", {
		"const HUB_PROMPT_TEXT := \"E / Y  •  HERO & BASE LOADOUT\"": "const HUB_PROMPT_TEXT := \"E / Y  •  CHOOSE BASE\""
	})
	_patch_file("res://scripts/systems/single_player_world_controller.gd", {
		"hub_title.text = \"BASE HUB  •  CHANGE HERO + BASE AT THE CORE\"": "hub_title.text = \"HERO HALL  •  HEROES AT ALTARS  •  BASE AT THE CORE\"",
		"_set_status(\"%s + %s ready. Press E / Y at the base to change loadout, then dig toward MineWars, Adventure, or LineWars.\" % [Global.selected_hero_id, base_name])": "_set_status(\"%s + %s ready. Approach a hero altar to change hero, use the central base to change fortress, then enter a route.\" % [Global.selected_hero_id, base_name])",
		"_set_status(\"FIRST EXPEDITION  •  Press E / Y at the base to inspect your Dwarf loadout, then dig down into MineWars. One victory unlocks all heroes, bases, and modes.\")": "_set_status(\"FIRST EXPEDITION  •  Approach the Dwarf altar for abilities. The central base changes your fortress. Then enter MineWars.\")"
	})
	get_tree().quit()

func _patch_file(path: String, replacements: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		push_error("Could not read %s" % path)
		return
	for before in replacements:
		var after: String = replacements[before]
		if not source.contains(before):
			push_warning("Patch text not found in %s: %s" % [path, before])
			continue
		source = source.replace(before, after)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(source)
	file.close()
