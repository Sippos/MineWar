extends Node

const SCRIPT_PATH := "res://online_lobby.gd"
const SCENE_PATH := "res://online_lobby.tscn"

func _ready() -> void:
	var script_source := FileAccess.get_file_as_string(SCRIPT_PATH)
	var scene_source := FileAccess.get_file_as_string(SCENE_PATH)
	if script_source.is_empty() or scene_source.is_empty():
		push_error("Could not read online lobby files")
		get_tree().quit(1)
		return

	script_source = script_source.replace(
		"\t_apply_main_menu_typography()\n",
		"\t_apply_main_menu_typography()\n\thelper_label.visible = false\n"
	)
	script_source = script_source.replace(
		"\tvar panel_height := clampf(size.y * 0.66, 350.0, 420.0)\n",
		"\tvar panel_height := clampf(size.y * 0.60, 330.0, 390.0)\n"
	)
	script_source = script_source.replace(
		"\tstatus_label.custom_minimum_size.y = 42.0 if compact else 48.0\n",
		"\tstatus_label.custom_minimum_size.y = 34.0 if compact else 38.0\n"
	)
	script_source = script_source.replace(
		"\thelper_label.add_theme_font_size_override(\"font_size\", 9 if compact else 10)\n",
		"\thelper_label.visible = false\n"
	)

	scene_source = scene_source.replace(
		"custom_minimum_size = Vector2(520, 420)",
		"custom_minimum_size = Vector2(520, 390)"
	)
	scene_source = scene_source.replace(
		"text = \"Host your compact stronghold or join a friend's private password.\"",
		"text = \"HOST OR JOIN WITH A PRIVATE PASSWORD\""
	)
	scene_source = scene_source.replace(
		"placeholder_text = \"PRIVATE PASSWORD  •  e.g. IRONMINE\"",
		"placeholder_text = \"PRIVATE PASSWORD\""
	)
	scene_source = scene_source.replace(
		"text = \"PRIVATE STRONGHOLD CONNECTION\"",
		"text = \"\"\nvisible = false"
	)

	var script_file := FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	var scene_file := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	if script_file == null or scene_file == null:
		push_error("Could not write online lobby files")
		get_tree().quit(1)
		return
	script_file.store_string(script_source)
	script_file.close()
	scene_file.store_string(scene_source)
	scene_file.close()
	print("ONLINE_LOBBY_COMPACT_LAYOUT_FINISHED")
	get_tree().quit()
