extends Node

func _ready() -> void:
	var path := "res://hero_abilities.gd"
	var text := FileAccess.get_file_as_string(path)

	var old_starting := "\t\tHERO_SHAMAN:\n\t\t\ttotem_level = 1\n\t\tHERO_NERUBIAN:\n\t\t\tbrood_level = 1"
	var new_starting := "\t\tHERO_SHAMAN:\n\t\t\tif totem_level <= 0:\n\t\t\t\ttotem_level = 1\n\t\tHERO_NERUBIAN:\n\t\t\tif brood_level <= 0:\n\t\t\t\tbrood_level = 1"
	if text.contains(old_starting):
		text = text.replace(old_starting, new_starting)
	elif not text.contains(new_starting):
		push_error("Starter skill block not found")
		get_tree().quit(1)
		return

	var old_rebuild := "func _rebuild_hud() -> void:\n\tif ability_bar == null or not is_instance_valid(ability_bar):\n\t\treturn"
	var new_rebuild := "func _rebuild_hud() -> void:\n\tif ability_bar == null or not is_instance_valid(ability_bar):\n\t\treturn\n\t_initialize_starting_skill()"
	if text.contains(old_rebuild):
		text = text.replace(old_rebuild, new_rebuild)
	elif not text.contains(new_rebuild):
		push_error("HUD rebuild block not found")
		get_tree().quit(1)
		return

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open hero_abilities.gd for writing")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("STARTER_SKILL_INITIALIZATION_FIXED")
	get_tree().quit()
