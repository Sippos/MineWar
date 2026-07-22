extends Node

const MENU_PATH := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(MENU_PATH)
	if source.is_empty():
		push_error("Could not read %s" % MENU_PATH)
		get_tree().quit(1)
		return

	source = _replace_once(
		source,
		"const DISPLAY_FONT: FontFile = preload(\"res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf\")",
		"const MENU_FONT: FontFile = preload(\"res://assets/fonts/cinzel/Cinzel-Variable.ttf\")\nconst DECORATIVE_FONT: FontFile = preload(\"res://assets/fonts/grenze_gotisch/GrenzeGotisch-Variable.ttf\")\nconst HEADER_LOGO: Texture2D = preload(\"res://HeaderLogo.png\")"
	)

	source = _replace_once(
		source,
		"\t$Label.text = \"MINEWARS\"",
		"\t$Label.visible = false\n\t_ensure_logo_header()"
	)

	var old_font_block := "func _apply_display_font() -> void:\n\tvar title_font := _make_display_font(900.0)\n\tvar button_font := _make_display_font(760.0)\n\tvar detail_font := _make_display_font(600.0)\n\n\t$Label.add_theme_font_override(\"font\", title_font)\n\t$Label.add_theme_color_override(\"font_color\", Color(1.0, 0.82, 0.31, 1.0))\n\t$Label.add_theme_color_override(\"font_outline_color\", Color(0.035, 0.018, 0.008, 1.0))\n\n\tfor button in [single_player_button, local_multiplayer_button, online_multiplayer_button]:\n\t\tbutton.add_theme_font_override(\"font\", button_font)\n\t\tbutton.add_theme_font_size_override(\"font_size\", 19)\n\t\tbutton.add_theme_color_override(\"font_color\", Color(1.0, 0.9, 0.72, 1.0))\n\t\tbutton.add_theme_color_override(\"font_hover_color\", Color(1.0, 0.98, 0.82, 1.0))\n\t\tbutton.add_theme_color_override(\"font_pressed_color\", Color(1.0, 0.72, 0.32, 1.0))\n\t\tbutton.add_theme_color_override(\"font_focus_color\", Color(0.73, 0.93, 1.0, 1.0))\n\t\tbutton.add_theme_color_override(\"font_outline_color\", Color(0.03, 0.012, 0.006, 0.98))\n\t\tbutton.add_theme_constant_override(\"outline_size\", 2)\n\n\tvar tagline := get_node_or_null(\"ReleaseTagline\") as Label\n\tif tagline:\n\t\ttagline.add_theme_font_override(\"font\", detail_font)\n\n\tvar lexicon_caption := _ensure_lexicon_caption()\n\tlexicon_caption.add_theme_font_override(\"font\", button_font)\n\tvar lexicon_hint := _ensure_lexicon_hint()\n\tlexicon_hint.add_theme_font_override(\"font\", detail_font)\n\nfunc _make_display_font(weight: float) -> FontVariation:\n\tvar font := FontVariation.new()\n\tfont.base_font = DISPLAY_FONT\n\tfont.variation_opentype = {\"wght\": weight}\n\treturn font\n"

	var new_font_block := "func _apply_display_font() -> void:\n\tvar button_font := _make_font_variation(MENU_FONT, 700.0)\n\tvar detail_font := _make_font_variation(MENU_FONT, 600.0)\n\tvar decorative_heading := _make_font_variation(DECORATIVE_FONT, 760.0)\n\tvar decorative_detail := _make_font_variation(DECORATIVE_FONT, 600.0)\n\n\tfor button in [single_player_button, local_multiplayer_button, online_multiplayer_button]:\n\t\tbutton.add_theme_font_override(\"font\", button_font)\n\t\tbutton.add_theme_font_size_override(\"font_size\", 18)\n\t\tbutton.add_theme_color_override(\"font_color\", Color(1.0, 0.9, 0.72, 1.0))\n\t\tbutton.add_theme_color_override(\"font_hover_color\", Color(1.0, 0.98, 0.82, 1.0))\n\t\tbutton.add_theme_color_override(\"font_pressed_color\", Color(1.0, 0.72, 0.32, 1.0))\n\t\tbutton.add_theme_color_override(\"font_focus_color\", Color(0.73, 0.93, 1.0, 1.0))\n\t\tbutton.add_theme_color_override(\"font_outline_color\", Color(0.03, 0.012, 0.006, 0.98))\n\t\tbutton.add_theme_constant_override(\"outline_size\", 2)\n\n\tvar tagline := get_node_or_null(\"ReleaseTagline\") as Label\n\tif tagline:\n\t\ttagline.add_theme_font_override(\"font\", detail_font)\n\n\tvar lexicon_caption := _ensure_lexicon_caption()\n\tlexicon_caption.add_theme_font_override(\"font\", decorative_heading)\n\tvar lexicon_hint := _ensure_lexicon_hint()\n\tlexicon_hint.add_theme_font_override(\"font\", decorative_detail)\n\nfunc _make_font_variation(base_font: Font, weight: float) -> FontVariation:\n\tvar font := FontVariation.new()\n\tfont.base_font = base_font\n\tfont.variation_opentype = {\"wght\": weight}\n\treturn font\n\nfunc _ensure_logo_header() -> TextureRect:\n\tvar existing := get_node_or_null(\"LogoHeader\") as TextureRect\n\tif existing != null:\n\t\treturn existing\n\tvar logo := TextureRect.new()\n\tlogo.name = \"LogoHeader\"\n\tlogo.texture = HEADER_LOGO\n\tlogo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n\tlogo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED\n\tlogo.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tlogo.z_index = 4\n\tadd_child(logo)\n\treturn logo\n"
	source = _replace_once(source, old_font_block, new_font_block)

	var old_layout_block := "\t$Label.offset_left = center_x - title_width * 0.5\n\t$Label.offset_top = title_top\n\t$Label.offset_right = center_x + title_width * 0.5\n\t$Label.offset_bottom = title_top + float(title_font_size) + 8.0\n\t$Label.add_theme_font_size_override(\"font_size\", title_font_size)\n\t$Label.add_theme_constant_override(\"outline_size\", 4)\n\tvar tagline := get_node_or_null(\"ReleaseTagline\") as Label\n\tif tagline:\n\t\ttagline.offset_left = center_x - title_width * 0.5\n\t\ttagline.offset_top = $Label.offset_bottom - 2.0\n\t\ttagline.offset_right = center_x + title_width * 0.5\n\t\ttagline.offset_bottom = tagline.offset_top + 24.0\n"
	var new_layout_block := "\tvar logo_width := float(layout[\"logo_width\"])\n\tvar logo_height := float(layout[\"logo_height\"])\n\tvar logo := _ensure_logo_header()\n\tlogo.offset_left = center_x - logo_width * 0.5\n\tlogo.offset_top = title_top\n\tlogo.offset_right = center_x + logo_width * 0.5\n\tlogo.offset_bottom = title_top + logo_height\n\n\t# Keep the legacy title node as a hidden layout anchor for existing tests/tools.\n\t$Label.visible = false\n\t$Label.offset_left = logo.offset_left\n\t$Label.offset_top = logo.offset_top\n\t$Label.offset_right = logo.offset_right\n\t$Label.offset_bottom = logo.offset_bottom\n\t$Label.add_theme_font_size_override(\"font_size\", title_font_size)\n\n\tvar tagline := get_node_or_null(\"ReleaseTagline\") as Label\n\tif tagline:\n\t\ttagline.offset_left = center_x - title_width * 0.5\n\t\ttagline.offset_top = logo.offset_bottom - 7.0\n\t\ttagline.offset_right = center_x + title_width * 0.5\n\t\ttagline.offset_bottom = tagline.offset_top + 22.0\n"
	source = _replace_once(source, old_layout_block, new_layout_block)

	var old_layout_math := "\tvar title_font_size := int(clampf(minf(screen_size.x * 0.09, screen_size.y * 0.095), 30.0, 48.0))\n\tvar title_top := clampf(screen_size.y * (0.075 if compact else 0.095), 18.0, 64.0)\n\tvar title_width := clampf(screen_size.x * 0.52, 220.0, 520.0)\n\tvar button_width := clampf(screen_size.x * 0.44, 210.0, 270.0)\n\tvar button_height := 46.0 if compact else 52.0\n\tvar gap := 8.0 if compact else 10.0\n\tvar minimum_top := title_top + float(title_font_size) + (24.0 if compact else 34.0)"
	var new_layout_math := "\tvar title_font_size := int(clampf(minf(screen_size.x * 0.09, screen_size.y * 0.095), 30.0, 48.0))\n\tvar title_top := clampf(screen_size.y * (0.032 if compact else 0.035), 10.0, 28.0)\n\tvar logo_width := clampf(screen_size.x * (0.55 if compact else 0.35), 220.0, 400.0)\n\tvar logo_aspect := float(HEADER_LOGO.get_width()) / maxf(float(HEADER_LOGO.get_height()), 1.0)\n\tvar logo_height := logo_width / maxf(logo_aspect, 1.0)\n\tvar title_width := logo_width\n\tvar button_width := clampf(screen_size.x * 0.44, 210.0, 270.0)\n\tvar button_height := 46.0 if compact else 52.0\n\tvar gap := 8.0 if compact else 10.0\n\tvar minimum_top := title_top + logo_height + (12.0 if compact else 24.0)"
	source = _replace_once(source, old_layout_math, new_layout_math)

	source = _replace_once(
		source,
		"\t\t\"title_width\": title_width,",
		"\t\t\"title_width\": title_width,\n\t\t\"logo_width\": logo_width,\n\t\t\"logo_height\": logo_height,"
	)

	var file := FileAccess.open(MENU_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % MENU_PATH)
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("MINEWARS_LOGO_AND_MENU_FONT_APPLIED")
	get_tree().quit(0)

func _replace_once(source: String, before: String, after: String) -> String:
	if source.contains(after):
		return source
	if not source.contains(before):
		push_error("Expected patch block was not found: %s" % before.left(100))
		get_tree().quit(1)
		return source
	return source.replace(before, after)
