extends Node

var failures: Array[String] = []
var changed: Array[String] = []

func _ready() -> void:
	_patch_main_menu()
	_patch_hero_selection()
	_patch_lexicon()
	if failures.is_empty():
		print("MENU_JOURNEY_CONSISTENCY_PATCH_OK changed=", changed)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_main_menu() -> void:
	var path := "res://scripts/ui/menus/main/menu.gd"
	_replace_once(
		path,
		"\tadvanced_modes_button.disabled = not Global.first_level_beaten\n",
		"\tadvanced_modes_button.disabled = not Global.first_level_beaten\n\tadvanced_modes_button.add_theme_color_override(\"font_disabled_color\", Color(0.58, 0.5, 0.38, 1.0))\n"
	)
	_replace_once(
		path,
		"\tvar panel := $MenuPanel as Sprite2D\n\tpanel.position = Vector2(center_x, screen_size.y * 0.5)\n\tvar panel_scale := clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)\n\tpanel.scale = Vector2(panel_scale, panel_scale * 1.18)\n",
		"\tvar panel := $MenuPanel as Sprite2D\n\tpanel.position = Vector2(center_x, screen_size.y * 0.55)\n\tvar panel_scale := clampf(minf(screen_size.x / 820.0, screen_size.y / 650.0), 0.42, 0.96)\n\tvar texture_height := maxf(float(panel.texture.get_height()), 1.0) if panel.texture else 314.0\n\tvar desired_panel_height := float(layout[\"stack_height\"]) + 72.0\n\tvar panel_y_scale := maxf(panel_scale * 1.18, desired_panel_height / texture_height)\n\tpanel.scale = Vector2(panel_scale, panel_y_scale)\n"
	)

func _patch_hero_selection() -> void:
	var path := "res://hero_selection_menu.gd"
	_replace_once(
		path,
		"func _apply_context_labels() -> void:\n",
		"func _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"ui_cancel\"):\n\t\t_on_back_pressed()\n\t\tget_viewport().set_input_as_handled()\n\nfunc _apply_context_labels() -> void:\n"
	)

func _patch_lexicon() -> void:
	var path := "res://scripts/ui/menus/lexicon/lexikon.gd"
	_replace_once(
		path,
		"\tpopulate_monsters()\n\t_update_grid_columns()\n\tget_tree().root.size_changed.connect(_update_grid_columns)\n",
		"\tpopulate_monsters()\n\t$VBoxContainer/TopBar/Label.text = \"MINEWARS BESTIARY\"\n\t_update_grid_columns()\n\tget_tree().root.size_changed.connect(_update_grid_columns)\n\tback_btn.call_deferred(\"grab_focus\")\n"
	)
	_replace_once(
		path,
		"func _on_back_pressed() -> void:\n",
		"func _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"ui_cancel\"):\n\t\t_on_back_pressed()\n\t\tget_viewport().set_input_as_handled()\n\nfunc _on_back_pressed() -> void:\n"
	)
	_replace_function(path, "func _update_grid_columns() -> void:", "func populate_heroes() -> void:", '''func _update_grid_columns() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var columns := 6 if viewport_width >= 1000.0 else (5 if viewport_width >= 820.0 else (4 if viewport_width >= 620.0 else (3 if viewport_width >= 460.0 else 2)))
	var grids: Array[GridContainer] = [
		$VBoxContainer/ScrollContainer/VBoxContainer/HeroesGrid,
		$VBoxContainer/ScrollContainer/VBoxContainer/BasesGrid,
		$VBoxContainer/ScrollContainer/VBoxContainer/MonstersGrid,
	]
	for grid in grids:
		grid.columns = columns

''')
	_replace_once(
		path,
		"\tframe_style.bg_color = Color(0.035, 0.045, 0.065, 0.96)\n",
		"\tframe_style.bg_color = Color(0.075, 0.038, 0.018, 0.96)\n"
	)

func _replace_function(path: String, start_marker: String, end_marker: String, replacement: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	var start := source.find(start_marker)
	if start < 0:
		if source.contains(replacement):
			return
		failures.append("Missing function start in %s: %s" % [path, start_marker])
		return
	var finish := source.find(end_marker, start)
	if finish < 0:
		failures.append("Missing function end in %s: %s" % [path, end_marker])
		return
	_write(path, source.substr(0, start) + replacement + source.substr(finish))

func _replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Patch target missing in %s: %s" % [path, old_text.left(120)])
		return
	_write(path, source.replace(old_text, new_text))

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(text)
	file.close()
	if not changed.has(path):
		changed.append(path)
