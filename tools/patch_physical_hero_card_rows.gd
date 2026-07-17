extends Node

func _ready() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var source := FileAccess.get_file_as_string(path)
	var replacements := {
		"row.custom_minimum_size = Vector2(0, 36)": "row.custom_minimum_size = Vector2(0, 30)",
		"icon_frame.custom_minimum_size = Vector2(32, 32)": "icon_frame.custom_minimum_size = Vector2(28, 28)",
		"description.add_theme_font_size_override(\"font_size\", 9)\n\tdescription.add_theme_color_override": "description.add_theme_font_size_override(\"font_size\", 9)\n\tdescription.visible = false\n\tdescription.add_theme_color_override"
	}
	for before in replacements:
		if not source.contains(before):
			push_warning("Missing replacement: %s" % before)
			continue
		source = source.replace(before, replacements[before])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(source)
		file.close()
	get_tree().quit()
