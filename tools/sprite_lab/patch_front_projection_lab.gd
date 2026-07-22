extends Node

func _ready() -> void:
	var canvas_path := "res://tools/sprite_lab/terrain_interaction_canvas.gd"
	var source := FileAccess.get_file_as_string(canvas_path)

	var enum_anchor := "enum LightingMode {\n\tNEUTRAL,\n\tMINE,\n\tPLAYER,\n\tDARK\n}\n"
	var enum_insert := enum_anchor + "\nenum FrontProjectionMode {\n\tFLAT_1X1,\n\tLIVE_FULL_TILE,\n\tFACE_ONLY_34PX\n}\n"
	if not source.contains(enum_anchor):
		push_error("Front projection enum anchor missing")
		get_tree().quit(1)
		return
	source = source.replace(enum_anchor, enum_insert)

	var var_anchor := "var current_tool: int = Tool.DIG\nvar lighting_mode: int = LightingMode.MINE\n"
	var var_insert := "var current_tool: int = Tool.DIG\nvar lighting_mode: int = LightingMode.MINE\nvar front_projection_mode: int = FrontProjectionMode.FACE_ONLY_34PX\n"
	source = source.replace(var_anchor, var_insert)

	var method_anchor := "func set_lighting_mode(value: int) -> void:\n\tlighting_mode = clampi(value, LightingMode.NEUTRAL, LightingMode.DARK)\n\tqueue_redraw()\n\t_emit_state()\n"
	var method_insert := method_anchor + "\nfunc set_front_projection_mode(value: int) -> void:\n\tfront_projection_mode = clampi(value, FrontProjectionMode.FLAT_1X1, FrontProjectionMode.FACE_ONLY_34PX)\n\tqueue_redraw()\n\t_emit_state()\n"
	if not source.contains(method_anchor):
		push_error("Front projection method anchor missing")
		get_tree().quit(1)
		return
	source = source.replace(method_anchor, method_insert)

	var draw_anchor := "\t# 3. Projected front walls are drawn into the free cell below their source block.\n\tif show_front_walls:\n\t\tfor y in range(MAP_SIZE.y):\n\t\t\tfor x in range(MAP_SIZE.x):\n\t\t\t\tvar cell := Vector2i(x, y)\n\t\t\t\tif not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):\n\t\t\t\t\tcontinue\n\t\t\t\tvar front_rect := _projected_front_rect(cell)\n\t\t\t\tif use_real_assets and front_texture != null:\n\t\t\t\t\tdraw_texture_rect(front_texture, front_rect, false, _lighting_modulate(cell, true))\n\t\t\t\telse:\n\t\t\t\t\tdraw_rect(Rect2(front_rect.position, Vector2(front_rect.size.x, front_rect.size.y * 0.42)), Color(\"4c435f\") * _lighting_modulate(cell, true))\n\t\t\t\t\tdraw_line(front_rect.position + Vector2(0, front_rect.size.y * 0.42), front_rect.position + Vector2(front_rect.size.x, front_rect.size.y * 0.42), Color(\"242035\"), 4)\n\t\t\t\t_draw_damage_for(cell, front_rect, true)\n\t\t\t\t_draw_gem_on_front(cell, front_rect)\n"
	var draw_insert := "\t# 3. The same 1x1 topology can be previewed with three visual contracts.\n\t# Flat shows pure Dome-style shells. Live Full Tile reproduces the current game.\n\t# Face Only keeps the 2.5D wall but removes the opaque lower half from the contract.\n\tif show_front_walls and front_projection_mode != FrontProjectionMode.FLAT_1X1:\n\t\tfor y in range(MAP_SIZE.y):\n\t\t\tfor x in range(MAP_SIZE.x):\n\t\t\t\tvar cell := Vector2i(x, y)\n\t\t\t\tif not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):\n\t\t\t\t\tcontinue\n\t\t\t\tvar front_rect := _projected_front_rect(cell)\n\t\t\t\tif front_projection_mode == FrontProjectionMode.FACE_ONLY_34PX:\n\t\t\t\t\tvar face_height := front_rect.size.y * (34.0 / 64.0)\n\t\t\t\t\tvar face_rect := Rect2(front_rect.position, Vector2(front_rect.size.x, face_height))\n\t\t\t\t\tif use_real_assets and front_texture != null:\n\t\t\t\t\t\tdraw_texture_rect_region(front_texture, face_rect, Rect2(Vector2.ZERO, Vector2(64, 34)), _lighting_modulate(cell, true))\n\t\t\t\t\telse:\n\t\t\t\t\t\tdraw_rect(face_rect, Color(\"4c435f\") * _lighting_modulate(cell, true))\n\t\t\t\t\t\tdraw_line(Vector2(face_rect.position.x, face_rect.end.y), face_rect.end, Color(\"242035\"), 3)\n\t\t\t\t\t# Diagnostics are deliberately clipped to the authored face depth.\n\t\t\t\t\t_draw_damage_for(cell, face_rect, true)\n\t\t\t\t\t_draw_gem_on_front(cell, face_rect)\n\t\t\t\telse:\n\t\t\t\t\tif use_real_assets and front_texture != null:\n\t\t\t\t\t\tdraw_texture_rect(front_texture, front_rect, false, _lighting_modulate(cell, true))\n\t\t\t\t\telse:\n\t\t\t\t\t\tdraw_rect(Rect2(front_rect.position, Vector2(front_rect.size.x, front_rect.size.y * 0.42)), Color(\"4c435f\") * _lighting_modulate(cell, true))\n\t\t\t\t\t\tdraw_line(front_rect.position + Vector2(0, front_rect.size.y * 0.42), front_rect.position + Vector2(front_rect.size.x, front_rect.size.y * 0.42), Color(\"242035\"), 4)\n\t\t\t\t\t_draw_damage_for(cell, front_rect, true)\n\t\t\t\t\t_draw_gem_on_front(cell, front_rect)\n"
	if not source.contains(draw_anchor):
		push_error("Front projection draw anchor missing")
		get_tree().quit(1)
		return
	source = source.replace(draw_anchor, draw_insert)

	var save_anchor := "\t\t\"player_light\": [player_light_cell.x, player_light_cell.y]\n\t}"
	var save_insert := "\t\t\"player_light\": [player_light_cell.x, player_light_cell.y],\n\t\t\"front_projection_mode\": front_projection_mode\n\t}"
	source = source.replace(save_anchor, save_insert)

	var load_anchor := "\tvar light_value: Variant = document.get(\"player_light\", [7, 6])\n"
	var load_insert := "\tfront_projection_mode = clampi(int(document.get(\"front_projection_mode\", FrontProjectionMode.FACE_ONLY_34PX)), FrontProjectionMode.FLAT_1X1, FrontProjectionMode.FACE_ONLY_34PX)\n\tvar light_value: Variant = document.get(\"player_light\", [7, 6])\n"
	source = source.replace(load_anchor, load_insert)

	var file := FileAccess.open(canvas_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch projection comparison")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()

	var editor_path := "res://tools/sprite_lab/golden_source_editor.gd"
	var editor_source := FileAccess.get_file_as_string(editor_path)
	var editor_var_anchor := "var lighting_selector: OptionButton\n"
	editor_source = editor_source.replace(editor_var_anchor, editor_var_anchor + "var projection_selector: OptionButton\n")
	var ui_anchor := "\tsidebar.add_child(lighting_selector)\n\n\t_add_section_label(sidebar, \"LAYER SWITCHES\")"
	var ui_insert := "\tsidebar.add_child(lighting_selector)\n\n\t_add_section_label(sidebar, \"2.5D PROJECTION CONTRACT\")\n\tprojection_selector = OptionButton.new()\n\tfor projection_name in [\"Flat 1x1 shell\", \"Current live full tile\", \"Recommended face-only 34px\"]:\n\t\tprojection_selector.add_item(projection_name)\n\tprojection_selector.select(2)\n\tprojection_selector.item_selected.connect(func(index: int) -> void:\n\t\tterrain_canvas.call(\"set_front_projection_mode\", index)\n\t)\n\tsidebar.add_child(projection_selector)\n\tvar projection_note := Label.new()\n\tprojection_note.text = \"All modes keep identical 1x1 collision/topology. Only visual depth and occlusion change.\"\n\tprojection_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tprojection_note.add_theme_font_size_override(\"font_size\", 11)\n\tprojection_note.add_theme_color_override(\"font_color\", Color.html(\"c6aa7fff\"))\n\tsidebar.add_child(projection_note)\n\n\t_add_section_label(sidebar, \"LAYER SWITCHES\")"
	if not editor_source.contains(ui_anchor):
		push_error("Projection UI anchor missing")
		get_tree().quit(1)
		return
	editor_source = editor_source.replace(ui_anchor, ui_insert)
	var editor_file := FileAccess.open(editor_path, FileAccess.WRITE)
	if editor_file == null:
		push_error("Could not patch projection UI")
		get_tree().quit(1)
		return
	editor_file.store_string(editor_source)
	editor_file.close()
	print("PATCHED_FRONT_PROJECTION_COMPARISON")
	get_tree().quit(0)
