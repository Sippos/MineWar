extends Node

func _patch(path: String, replacements: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s" % path)
		return false
	var source := file.get_as_text()
	file.close()
	var changed := false
	for old_text_value in replacements.keys():
		var old_text := str(old_text_value)
		var new_text := str(replacements[old_text_value])
		if source.contains(old_text):
			source = source.replace(old_text, new_text)
			changed = true
		else:
			push_error("Missing bool patch target in %s: %s" % [path, old_text])
	if not changed:
		return false
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write %s" % path)
		return false
	output.store_string(source)
	output.close()
	return true

func _ready() -> void:
	var ok := true
	ok = _patch(
		"res://scripts/systems/world_generation/siege_mode_controller.gd",
		{
			"if bool(world.get(\"is_vs_mode\")) or not GameMode.is_siege():": "if world.get(\"is_vs_mode\") == true or not GameMode.is_siege():",
			"if bool(world.get(\"preparation_active\")):": "if world.get(\"preparation_active\") == true:",
			"var previous_generation_flag := bool(world.world_generation_in_progress)": "var previous_generation_flag: bool = world.world_generation_in_progress",
		}
	) and ok
	ok = _patch(
		"res://base.gd",
		{
			"return world != null and bool(world.get(\"is_vs_mode\"))": "return world != null and world.get(\"is_vs_mode\") == true",
			"return world != null and bool(world.get_meta(\"single_player_hub_active\", false))": "return world != null and world.get_meta(\"single_player_hub_active\", false) == true",
		}
	) and ok
	if ok:
		print("MINEWARS_BOOL_CASTS_FIXED")
		get_tree().quit()
	else:
		get_tree().quit(1)
