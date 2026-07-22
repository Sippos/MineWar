extends Node

func _ready() -> void:
	var path := "res://scripts/ui/menus/settings_menu.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open settings menu script")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	var old_text := "\t\tvar row_icon := row_content.get_node(\"Icon\") as TextureRect"
	var new_text := "\t\tvar row_icon := row_content.get_node(\"Icon\") as Control"
	if not source.contains(old_text):
		push_error("Settings crash pattern was not found")
		get_tree().quit(1)
		return
	source = source.replace(old_text, new_text)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write settings menu script")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("SETTINGS_CRASH_FIX_APPLIED")
	get_tree().quit(0)
