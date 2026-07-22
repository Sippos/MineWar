extends Node

func _ready() -> void:
	var path := "res://scripts/ui/menus/loadout_selection_menu.gd"
	var source := FileAccess.get_file_as_string(path)
	var old := '''	for base_id in BASE_ORDER:
		var button: Button = base_buttons[base_id]
		var unlocked := _base_unlocked(base_id)
		var is_selected := base_id == selected_base
		var data: Dictionary = Global.base_data.get(base_id, {})
		var short_name := str(data.get("name", base_id.capitalize()))
		# The arrows own cycling; show one readable fortress name instead of a cramped strip.
		button.visible = unlocked and is_selected
		button.text = short_name
		button.disabled = not unlocked
		button.modulate = Color.WHITE
		button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0) if is_selected else Color(0.86, 0.9, 0.95, 1.0))
'''
	var new := '''	var available_count := maxi(_available_bases().size(), 1)
	var choice_width := clampf(552.0 / float(available_count), 92.0, 220.0)
	for base_id in BASE_ORDER:
		var button: Button = base_buttons[base_id]
		var unlocked := _base_unlocked(base_id)
		var is_selected := base_id == selected_base
		var data: Dictionary = Global.base_data.get(base_id, {})
		var short_name := str(data.get("name", base_id.capitalize()))
		button.visible = unlocked
		button.text = short_name
		button.disabled = not unlocked
		button.custom_minimum_size = Vector2(choice_width, 60)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if available_count >= 4 else TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", 12 if available_count >= 4 else 15)
		button.modulate = Color.WHITE
		button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48, 1.0) if is_selected else Color(0.86, 0.9, 0.95, 1.0))
'''
	if source.contains(new):
		print("FIX_ADAPTIVE_FORTRESS_SELECTOR_OK")
		get_tree().quit(0)
		return
	if not source.contains(old):
		push_error("Fortress selector patch target missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source.replace(old, new))
	file.close()
	print("FIX_ADAPTIVE_FORTRESS_SELECTOR_OK")
	get_tree().quit(0)
