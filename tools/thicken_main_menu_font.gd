extends Node

const MENU_PATH := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(MENU_PATH)
	if source.is_empty():
		push_error("Could not read main menu script")
		get_tree().quit(1)
		return

	source = _replace_once(source,
		"\tvar button_font := _make_font_variation(MENU_FONT, 700.0)\n\tvar detail_font := _make_font_variation(MENU_FONT, 600.0)",
		"\tvar button_font := _make_font_variation(MENU_FONT, 900.0, 0.85)\n\tvar detail_font := _make_font_variation(MENU_FONT, 650.0, 0.15)"
	)
	source = _replace_once(source,
		"\t\tbutton.add_theme_font_size_override(\"font_size\", 18)",
		"\t\tbutton.add_theme_font_size_override(\"font_size\", 20)"
	)
	source = _replace_once(source,
		"\t\tbutton.add_theme_color_override(\"font_color\", Color(1.0, 0.9, 0.72, 1.0))",
		"\t\tbutton.add_theme_color_override(\"font_color\", Color(1.0, 0.94, 0.8, 1.0))"
	)
	source = _replace_once(source,
		"\t\tbutton.add_theme_constant_override(\"outline_size\", 2)",
		"\t\tbutton.add_theme_constant_override(\"outline_size\", 3)\n\t\tbutton.add_theme_color_override(\"font_shadow_color\", Color(0.0, 0.0, 0.0, 0.82))\n\t\tbutton.add_theme_constant_override(\"shadow_offset_x\", 1)\n\t\tbutton.add_theme_constant_override(\"shadow_offset_y\", 2)\n\t\tbutton.add_theme_constant_override(\"shadow_outline_size\", 1)"
	)
	source = _replace_once(source,
		"func _make_font_variation(base_font: Font, weight: float) -> FontVariation:\n\tvar font := FontVariation.new()\n\tfont.base_font = base_font\n\tfont.variation_opentype = {\"wght\": weight}\n\treturn font",
		"func _make_font_variation(base_font: Font, weight: float, embolden: float = 0.0) -> FontVariation:\n\tvar font := FontVariation.new()\n\tfont.base_font = base_font\n\tfont.variation_opentype = {\"wght\": weight}\n\tfont.variation_embolden = embolden\n\treturn font"
	)

	var file := FileAccess.open(MENU_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write main menu script")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("MINEWARS_MAIN_MENU_FONT_THICKENED")
	get_tree().quit(0)

func _replace_once(source: String, before: String, after: String) -> String:
	if source.contains(after):
		return source
	if not source.contains(before):
		push_error("Expected patch text missing: %s" % before.left(120))
		get_tree().quit(1)
		return source
	return source.replace(before, after)
