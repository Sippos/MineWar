extends Node

func _ready() -> void:
	var replacements := {
		"res://scenes/menus/settings_menu.tscn": "theme_override_styles/panel = SubResource(\"StyleBox_settings\")\n",
		"res://scenes/menus/multiplayer_menu.tscn": "theme_override_styles/panel = SubResource(\"StyleBox_multiplayer\")\n",
		"res://scenes/menus/multiplayer_hero_select.tscn": "theme_override_styles/panel = SubResource(\"StyleBox_hero_select\")\n",
	}
	for path in replacements:
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			push_error("Could not read %s" % path)
			get_tree().quit(1)
			return
		source = source.replace(str(replacements[path]), "")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not write %s" % path)
			get_tree().quit(1)
			return
		file.store_string(source)
		file.close()
	print("REMOVE_CONCURRENT_STYLE_DUPLICATES_OK")
	get_tree().quit(0)
