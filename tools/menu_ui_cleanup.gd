extends Node

func _ready() -> void:
	var targets := {
		"res://scenes/menus/settings_menu.tscn": "theme_override_styles/panel = SubResource(\"StyleBox_settings\")\n",
		"res://scenes/menus/multiplayer_menu.tscn": "theme_override_styles/panel = SubResource(\"StyleBox_multiplayer\")\n",
		"res://scenes/menus/multiplayer_hero_select.tscn": "theme_override_styles/panel = SubResource(\"StyleBox_hero_select\")\n",
	}
	for path in targets:
		var source := FileAccess.get_file_as_string(path)
		if source.contains(targets[path]):
			source = source.replace(targets[path], "")
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(source)
			file.close()
	print("MENU_UI_CLEANUP_OK")
	get_tree().quit(0)
