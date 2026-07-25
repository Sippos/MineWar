import re

with open("scripts/systems/preparation/in_world_hero_selector.gd", "r") as f:
    code = f.read()

code = code.replace('const CARD_SIZE := Vector2(310, 330)', 'const CARD_SIZE := Vector2(380, 450)')
code = code.replace('header.custom_minimum_size = Vector2(0, 62)', 'header.custom_minimum_size = Vector2(0, 84)')
code = code.replace('portrait_frame.custom_minimum_size = Vector2(62, 62)', 'portrait_frame.custom_minimum_size = Vector2(84, 84)')

code = code.replace('card_title.add_theme_font_size_override("font_size", 20)', 'card_title.add_theme_font_size_override("font_size", 26)')
code = code.replace('card_role.add_theme_font_size_override("font_size", 11)', 'card_role.add_theme_font_size_override("font_size", 15)')
code = code.replace('card_state.add_theme_font_size_override("font_size", 11)', 'card_state.add_theme_font_size_override("font_size", 15)')
code = code.replace('card_description.add_theme_font_size_override("font_size", 11)', 'card_description.add_theme_font_size_override("font_size", 15)')
code = code.replace('abilities_heading.add_theme_font_size_override("font_size", 11)', 'abilities_heading.add_theme_font_size_override("font_size", 14)')
code = code.replace('card_action.add_theme_font_size_override("font_size", 12)', 'card_action.add_theme_font_size_override("font_size", 15)')
code = code.replace('title.add_theme_font_size_override("font_size", 11)', 'title.add_theme_font_size_override("font_size", 15)')
code = code.replace('description.add_theme_font_size_override("font_size", 9)', 'description.add_theme_font_size_override("font_size", 12)')

code = code.replace('row.custom_minimum_size = Vector2(0, 30)', 'row.custom_minimum_size = Vector2(0, 42)')
code = code.replace('icon_frame.custom_minimum_size = Vector2(28, 28)', 'icon_frame.custom_minimum_size = Vector2(40, 40)')

code = code.replace('card.scale = Vector2(0.66, 0.66)', 'card.scale = Vector2(0.85, 0.85)')
code = code.replace('card_tween.tween_property(card, "scale", Vector2(0.72, 0.72), 0.2)', 'card_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2)')
code = code.replace('card_tween.tween_property(card, "scale", Vector2(0.68, 0.68), 0.1)', 'card_tween.tween_property(card, "scale", Vector2(0.9, 0.9), 0.1)')

# Add logic to hide if MineWars mode started
process_func = """func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	var is_active_hub = true
	if world != null and world.get_parent().has_node("SinglePlayerWorldController"):
		is_active_hub = world.has_meta("single_player_hub_active")
	
	if not is_active_hub:
		if shrine_root and shrine_root.visible:
			shrine_root.visible = false
			_hide_card()
		return
	elif shrine_root and not shrine_root.visible:
		shrine_root.visible = true

	var closest := ""
"""

code = code.replace('func _process(_delta: float) -> void:\n\tif player == null or not is_instance_valid(player):\n\t\treturn\n\tvar closest := ""\n', process_func)

with open("scripts/systems/preparation/in_world_hero_selector.gd", "w") as f:
    f.write(code)

