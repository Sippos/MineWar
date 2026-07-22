extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing workbench anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)

	var old_ui := "\ttier_note.add_theme_color_override(\"font_color\", Color.html(\"8fa2afff\"))\n\tcontrols.add_child(tier_note)\n\n\t_add_section(controls, \"3 • PAINT\")"
	var new_ui := "\ttier_note.add_theme_color_override(\"font_color\", Color.html(\"8fa2afff\"))\n\tcontrols.add_child(tier_note)\n\tvar rebuild_corners_button := Button.new()\n\trebuild_corners_button.text = \"REBUILD JOINT + HOLE FROM BORDER\"\n\trebuild_corners_button.tooltip_text = \"Replace this material's Edge Joint and Hole Corner with freshly generated versions derived from its current Border. They remain independently editable afterward.\"\n\trebuild_corners_button.pressed.connect(_rebuild_current_corners_from_border)\n\tcontrols.add_child(rebuild_corners_button)\n\n\t_add_section(controls, \"3 • PAINT\")"
	text = _replace_once(text, old_ui, new_ui, "corner rebuild button")

	var old_function_anchor := "func _on_tier_selected(index: int) -> void:\n\tcurrent_tier = TIERS[clampi(index, 0, TIERS.size() - 1)]\n\tundo_stack.clear()\n\tredo_stack.clear()\n\t_refresh_workspace()\n\nfunc _visual_tier() -> String:"
	var new_function_anchor := "func _on_tier_selected(index: int) -> void:\n\tcurrent_tier = TIERS[clampi(index, 0, TIERS.size() - 1)]\n\tundo_stack.clear()\n\tredo_stack.clear()\n\t_refresh_workspace()\n\nfunc _rebuild_current_corners_from_border() -> void:\n\tvar tier := _visual_tier()\n\tif not border_images.has(tier):\n\t\tstatus_label.text = \"No border source exists for %s.\" % tier.to_upper()\n\t\treturn\n\tvar border := (border_images[tier] as Image).duplicate()\n\tvar rebuilt_joint := CORNER_BUILDER.make_edge_joint_top_left(mass_image, border)\n\tvar rebuilt_hole := CORNER_BUILDER.make_hole_corner_top_left(mass_image, border, rebuilt_joint)\n\tconvex_images[tier] = rebuilt_joint\n\tcorner_images[tier] = rebuilt_hole\n\tundo_stack.clear()\n\tredo_stack.clear()\n\t_refresh_workspace()\n\tstatus_label.text = \"Rebuilt %s Edge Joint and Hole Corner from its current Border. Save/export when approved.\" % tier.to_upper()\n\nfunc _visual_tier() -> String:"
	text = _replace_once(text, old_function_anchor, new_function_anchor, "corner rebuild function")

	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Added explicit border-to-corner rebuild workflow")
	get_tree().quit()
