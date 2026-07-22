extends Node

func _ready() -> void:
	var path := "res://tests/menu_journey_audit_runner.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\t_expect(menu.get_node(\"Dimmer\") is TextureRect, \"Online lobby should reuse the MineWars menu backdrop instead of a flat black/grey screen\")"
	var new_text := "\t_expect(menu.get_node(\"Dimmer/Background\") is TextureRect, \"Online lobby should reuse the MineWars menu backdrop instead of a flat black/grey screen\")"
	if source.contains(new_text):
		print("UPDATE_MENU_AUDIT_ONLINE_EXPECTATION_ALREADY_APPLIED")
		get_tree().quit(0)
		return
	if source.is_empty() or not source.contains(old_text):
		push_error("Menu audit online expectation target missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source.replace(old_text, new_text))
	file.close()
	print("UPDATE_MENU_AUDIT_ONLINE_EXPECTATION_OK")
	get_tree().quit(0)
