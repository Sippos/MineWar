extends Node

const TARGET := "res://tools/apply_online_lobby_main_menu_typography.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read online typography patch tool")
		get_tree().quit(1)
		return
	var old_text := "\t\tvar insertion := node_header + \"\\n\"\n"
	var new_text := "\t\tvar insertion: String = str(node_header) + \"\\n\"\n"
	if not source.contains(old_text):
		push_error("Could not find insertion type anchor")
		get_tree().quit(1)
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write online typography patch tool")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("ONLINE_TYPOGRAPHY_TOOL_TYPE_FIXED")
	get_tree().quit()
