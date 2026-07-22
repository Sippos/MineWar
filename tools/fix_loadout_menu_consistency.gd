extends Node

const PATH := "res://scripts/ui/menus/loadout_selection_menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(PATH)
	if source.is_empty():
		_fail("Could not read loadout menu script")
		return

	source = _replace_once(source, "extends CanvasLayer\n", "extends CanvasLayer\n\nconst MENU_PANEL_TEXTURE: Texture2D = preload(\"res://assets/sprites/ui/common/MenuPanel.png\")\n")
	source = _replace_once(source, "var base_buttons: Dictionary = {}\n", "var base_buttons: Dictionary = {}\nvar base_grid: GridContainer\nvar closing := false\n")
	source = _replace_once(source, "\tshell.add_theme_stylebox_override(\"panel\", _panel_style(Color(0.025, 0.032, 0.045, 0.99), Color(0.3, 0.78, 1.0, 1.0), 3, 16))", "\tshell.add_theme_stylebox_override(\"panel\", _wood_panel_style())")
	source = _replace_once(source, "\tshowcase.add_theme_stylebox_override(\"panel\", _panel_style(Color(0.045, 0.055, 0.07, 0.96), Color(0.22, 0.48, 0.64, 0.88), 2, 12))", "\tshowcase.add_theme_stylebox_override(\"panel\", _panel_style(Color(0.07, 0.038, 0.02, 0.96), Color(0.72, 0.45, 0.16, 0.9), 2, 12))")

	var selector_start := source.find("\tvar selector_row := HBoxContainer.new()")
	var selector_end := source.find("\n\tvar footer := HBoxContainer.new()", selector_start)
	if selector_start < 0 or selector_end < 0:
		_fail("Loadout selector block not found")
		return
	var selector_replacement := '''\tbase_grid = GridContainer.new()
\tbase_grid.name = "BaseChoices"
\tbase_grid.columns = 3
\tbase_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tbase_grid.add_theme_constant_override("h_separation", 8)
\tbase_grid.add_theme_constant_override("v_separation", 6)
\tbody.add_child(base_grid)

\tfor base_id in BASE_ORDER:
\t\tvar button := Button.new()
\t\tbutton.name = base_id.capitalize().replace(" ", "")
\t\tbutton.custom_minimum_size = Vector2(210, 48)
\t\tbutton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tbutton.add_theme_font_size_override("font_size", 14)
\t\tbutton.pressed.connect(_select_base.bind(base_id))
\t\tbase_grid.add_child(button)
\t\tbase_buttons[base_id] = button
'''
	source = source.substr(0, selector_start) + selector_replacement + source.substr(selector_end)

	source = _replace_once(source, "\tshell.offset_bottom = height * 0.5\n", "\tshell.offset_bottom = height * 0.5\n\tvar compact := view_size.x < 720.0 or view_size.y < 590.0\n\tbase_grid.columns = 2 if compact else 3\n\tvar available_button_width := maxf(126.0, (width - 72.0 - float(base_grid.columns - 1) * 8.0) / float(base_grid.columns))\n\tfor button_value in base_buttons.values():\n\t\tvar button := button_value as Button\n\t\tbutton.custom_minimum_size = Vector2(available_button_width, 40.0 if compact else 48.0)\n\t\tbutton.add_theme_font_size_override(\"font_size\", 12 if compact else 14)\n\tbase_texture.custom_minimum_size = Vector2(300, 150) if compact else Vector2(360, 205)\n")
	source = _replace_once(source, "\t\t# The arrows own cycling; show one readable fortress name instead of a cramped strip.\n\t\tbutton.visible = unlocked and is_selected", "\t\tbutton.visible = unlocked")
	source = _replace_once(source, "func _close_menu() -> void:\n\tif player != null and player.get(\"can_move\") != null:\n\t\tplayer.set(\"can_move\", true)\n\tqueue_free()\n", "func _close_menu() -> void:\n\tif closing:\n\t\treturn\n\tclosing = true\n\tif player != null and player.get(\"can_move\") != null:\n\t\tplayer.set(\"can_move\", true)\n\tget_tree().create_timer(0.2, true).timeout.connect(queue_free)\n")
	source = _replace_once(source, "func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:\n", '''func _wood_panel_style() -> StyleBoxTexture:
\tvar style := StyleBoxTexture.new()
\tstyle.texture = MENU_PANEL_TEXTURE
\tstyle.texture_margin_left = 34.0
\tstyle.texture_margin_top = 34.0
\tstyle.texture_margin_right = 34.0
\tstyle.texture_margin_bottom = 34.0
\tstyle.content_margin_left = 20.0
\tstyle.content_margin_top = 18.0
\tstyle.content_margin_right = 20.0
\tstyle.content_margin_bottom = 18.0
\treturn style

func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
''')

	if source.is_empty():
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write loadout menu script")
		return
	file.store_string(source)
	file.close()
	print("FIX_LOADOUT_MENU_CONSISTENCY_OK")
	get_tree().quit(0)

func _replace_once(source: String, old_text: String, new_text: String) -> String:
	if source.contains(new_text):
		return source
	if not source.contains(old_text):
		_fail("Missing loadout patch target: %s" % old_text.left(100))
		return ""
	return source.replace(old_text, new_text)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
