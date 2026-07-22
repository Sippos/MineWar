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
		"\ttagline.text = \"MINE • BUILD • RETURN • DEFEND\"",
		"\ttagline.text = \"\"\n\ttagline.visible = false"
	)

	source = _replace_once(
		source,
		"\tvar panel_scale := clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)\n\tvar texture_height := maxf(float(panel.texture.get_height()), 1.0) if panel.texture else 314.0\n\tvar desired_panel_height := float(layout[\"stack_height\"]) + 96.0\n\tvar panel_y_scale := maxf(panel_scale * 0.88, desired_panel_height / texture_height)\n\tpanel.scale = Vector2(panel_scale, panel_y_scale)",
		"\tvar panel_scale := clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)\n\tvar texture_height := maxf(float(panel.texture.get_height()), 1.0) if panel.texture else 314.0\n\tvar desired_panel_height := float(layout[\"stack_height\"]) + 90.0\n\tvar panel_y_scale := maxf(panel_scale * 0.88, desired_panel_height / texture_height)\n\tvar panel_x_scale := panel_scale * (0.82 if bool(layout[\"compact\"]) else 0.86)\n\tpanel.scale = Vector2(panel_x_scale, panel_y_scale)"
	)

	source = _replace_once(
		source,
		"\tvar logo_width := clampf(screen_size.x * (0.55 if compact else 0.35), 220.0, 400.0)",
		"\tvar logo_width := clampf(screen_size.x * (0.50 if compact else 0.30), 210.0, 340.0)"
	)

	source = _replace_once(
		source,
		"\tvar button_width := clampf(screen_size.x * 0.44, 210.0, 270.0)\n\tvar button_height := 46.0 if compact else 52.0\n\tvar gap := 8.0 if compact else 10.0\n\tvar minimum_top := title_top + logo_height + (12.0 if compact else 24.0)",
		"\tvar button_width := clampf(screen_size.x * 0.40, 218.0, 252.0)\n\tvar button_height := 50.0 if compact else 58.0\n\tvar gap := 9.0 if compact else 12.0\n\tvar minimum_top := title_top + logo_height + (8.0 if compact else 12.0)"
	)

	var file := FileAccess.open(MENU_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % MENU_PATH)
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("MINEWARS_MAIN_MENU_PROPORTIONS_REFINED")
	get_tree().quit(0)

func _replace_once(source: String, before: String, after: String) -> String:
	if source.contains(after):
		return source
	if not source.contains(before):
		push_error("Expected patch block not found: %s" % before.left(120))
		get_tree().quit(1)
		return source
	return source.replace(before, after)
