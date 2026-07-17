extends Node

func _ready() -> void:
	var ability_path := "res://hero_abilities.gd"
	var ability_text := FileAccess.get_file_as_string(ability_path)
	var old_block := "\tif hero != current_hud_hero:\n\t\t_rebuild_hud()"
	var new_block := "\tif hero != current_hud_hero:\n\t\t_initialize_starting_skill()\n\t\t_rebuild_hud()"
	if not ability_text.contains(old_block):
		push_error("Hero-change initialization block not found")
		get_tree().quit(1)
		return
	ability_text = ability_text.replace(old_block, new_block)
	var ability_file := FileAccess.open(ability_path, File