extends Node

func _ready() -> void:
	var ability_path := "res://hero_abilities.gd"
	var ability_text := FileAccess.get_file_as_string(ability_path)
	var old_block := "\tif hero != current_hud_hero:\n\t\t_rebuild_hud()"
	var new_block := "\tif hero != current_hud_hero:\n\t\t_initialize_starting_skill()\n\t\t_rebuild_hud()"
	if ability_text.contains(old_block):
		ability_text = ability_text.replace(old_block, new_block)
	elif not ability_text.contains(new_block):
		push_error("Hero-change initialization block not found")
		get_tree().quit(1)
		return
	var ability_file := FileAccess.open(ability_path, FileAccess.WRITE)
	if ability_file == null:
		push_error("Could not open hero_abilities.gd for writing")
		get_tree().quit(1)
		return
	ability_file.store_string(ability_text)
	ability_file.close()

	var smoke_path := "res://tests/hero_balance_smoke_runner.gd"
	var smoke_text := FileAccess.get_file_as_string(smoke_path)
	smoke_text = smoke_text.replace("\t\t_validate_level_up_menu(hero, level, player, abilities)", "\t\tawait _validate_level_up_menu(hero, level, player, abilities)")
	var smoke_file := FileAccess.open(smoke_path, FileAccess.WRITE)
	if smoke_file == null:
		push_error("Could not open hero balance smoke runner for writing")
		get_tree().quit(1)
		return
	smoke_file.store_string(smoke_text)
	smoke_file.close()
	print("HERO_CHANGE_INITIALIZATION_PATCH_APPLIED")
	get_tree().quit()
