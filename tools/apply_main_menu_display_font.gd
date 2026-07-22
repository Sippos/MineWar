extends Node

const TARGET := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read %s" % TARGET)
		get_tree().quit(1)
		return

	source = _replace_once(
		source,
		"const MENU_THEME = preload(\"res://assets/themes/global/global_theme.tres\")\n",
		"const MENU_THEME = preload(\"res://assets/themes/global/global_theme.tres\")\nconst DISPLAY_FONT: FontFile = preload(\"res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf\")\n"
	)
	source = _replace_once(
		source,
		"\t_configure_lexicon_action()\n\tget_tree().root.size_changed.connect(_layout_for_screen)\n",
		"\t_configure_lexicon_action()\n\t_apply_display_font()\n\tget_tree().root.size_changed.connect(_layout_for_screen)\n"
	)
	source = _replace_once(
		source,
		"\ttagline.text = \"MINE • BUILD • RETURN • DEFEND\"\n\nfunc _configure_utility_button",
		"\ttagline.text = \"MINE • BUILD • RETURN • DEFEND\"\n\nfunc _apply_display_font() -> void:\n\tvar title_font := _make_display_font(900.0)\n\tvar button_font := _make_display_font(760.0)\n\tvar detail_font := _make_display_font(600.0)\n\n\t$Label.add_theme_font_override(\"font\", title_font)\n\t$Label.add_theme_color_override(\"font_color\", Color(1.0, 0.82, 0.31, 1.0))\n\t$Label.add_theme_color_override(\"font_outline_color\", Color(0.035, 0.018, 0.008, 1.0))\n\n\tfor button in [single_player_button, local_multiplayer_button, online_multiplayer_button]:\n\t\tbutton.add_theme_font_override(\"font\", button_font)\n\t\tbutton.add_theme_font_size_override(\"font_size\", 19)\n\t\tbutton.add_theme_color_override(\"font_color\", Color(1.0, 0.9, 0.72, 1.0))\n\t\tbutton.add_theme_color_override(\"font_hover_color\", Color(1.0, 0.98, 0.82, 1.0))\n\t\tbutton.add_theme_color_override(\"font_pressed_color\", Color(1.0, 0.72, 0.32, 1.0))\n\t\tbutton.add_theme_color_override(\"font_focus_color\", Color(0.73, 0.93, 1.0, 1.0))\n\t\tbutton.add_theme_color_override(\"font_outline_color\", Color(0.03, 0.012, 0.006, 0.98))\n\t\tbutton.add_theme_constant_override(\"outline_size\", 2)\n\n\tvar tagline := get_node_or_null(\"ReleaseTagline\") as Label\n\tif tagline:\n\t\ttagline.add_theme_font_override(\"font\", detail_font)\n\n\tvar lexicon_caption := _ensure_lexicon_caption()\n\tlexicon_caption.add_theme_font_override(\"font\", button_font)\n\tvar lexicon_hint := _ensure_lexicon_hint()\n\tlexicon_hint.add_theme_font_override(\"font\", detail_font)\n\nfunc _make_display_font(weight: float) -> FontVariation:\n\tvar font := FontVariation.new()\n\tfont.base_font = DISPLAY_FONT\n\tfont.variation_opentype = {TextServer.name_to_tag(\"wght\"): weight}\n\treturn font\n\nfunc _configure_utility_button"
	)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % TARGET)
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("MINEWARS_DISPLAY_FONT_APPLIED")
	get_tree().quit(0)

func _replace_once(source: String, old_text: String, new_text: String) -> String:
	if source.count(old_text) != 1:
		push_error("Expected exactly one patch target but found %d" % source.count(old_text))
		get_tree().quit(1)
		return source
	return source.replace(old_text, new_text)
