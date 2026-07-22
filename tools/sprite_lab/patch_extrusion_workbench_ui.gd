extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing workbench UI anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	text = _replace_once(
		text,
		"\ttier_note.text = \"Each material has one straight BORDER, one 14x14 EDGE JOINT, and one independent 14x14 HOLE CORNER. Their curves start matched but can be edited separately.\"",
		"\ttier_note.text = \"Each material has a BORDER, EDGE JOINT, HOLE CORNER and a FRONT SURFACE texture. The front surface is clipped into the exact rounded cave silhouette instead of being drawn as a square tile.\"",
		"tier note"
	)
	var old_preview := "\tvar preview_brush := OptionButton.new()\n\tfor brush_name in [\"DIG / EMPTY\", \"PAINT EASY\", \"PAINT MEDIUM\", \"PAINT HARD\", \"PAINT UNMINEABLE\"]:\n\t\tpreview_brush.add_item(brush_name)\n\tpreview_brush.item_selected.connect(func(index: int) -> void: preview.call(\"set_preview_brush\", index))\n\tcontrols.add_child(preview_brush)\n\tvar reset_button := Button.new()"
	var new_preview := "\tvar preview_brush := OptionButton.new()\n\tfor brush_name in [\"DIG / EMPTY\", \"PAINT EASY\", \"PAINT MEDIUM\", \"PAINT HARD\", \"PAINT UNMINEABLE\"]:\n\t\tpreview_brush.add_item(brush_name)\n\tpreview_brush.item_selected.connect(func(index: int) -> void: preview.call(\"set_preview_brush\", index))\n\tcontrols.add_child(preview_brush)\n\tvar front_toggle := CheckBox.new()\n\tfront_toggle.text = \"Generated shallow front extrusion\"\n\tfront_toggle.button_pressed = true\n\tfront_toggle.toggled.connect(func(value: bool) -> void: preview.call(\"set_front_faces_visible\", value))\n\tcontrols.add_child(front_toggle)\n\tvar depth_row := HBoxContainer.new()\n\tvar depth_label := Label.new()\n\tdepth_label.text = \"Front depth\"\n\tdepth_label.custom_minimum_size = Vector2(80, 0)\n\tdepth_row.add_child(depth_label)\n\tvar depth_slider := HSlider.new()\n\tdepth_slider.min_value = 2\n\tdepth_slider.max_value = 16\n\tdepth_slider.step = 1\n\tdepth_slider.value = 10\n\tdepth_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tdepth_row.add_child(depth_slider)\n\tvar depth_value := Label.new()\n\tdepth_value.text = \"10 px\"\n\tdepth_value.custom_minimum_size = Vector2(38, 0)\n\tdepth_row.add_child(depth_value)\n\tdepth_slider.value_changed.connect(func(value: float) -> void:\n\t\tpreview.call(\"set_front_depth\", roundi(value))\n\t\tdepth_value.text = \"%d px\" % roundi(value)\n\t)\n\tcontrols.add_child(depth_row)\n\tvar reset_button := Button.new()"
	text = _replace_once(text, old_preview, new_preview, "preview controls")
	text = _replace_once(
		text,
		"\texplanation.text = \"LEFT-DRAG removes mineable blocks. RIGHT-DRAG restores them. The outer ring always uses the UNMINEABLE border; inner rock uses the selected Easy/Medium/Hard border.\"",
		"\texplanation.text = \"Choose DIG or a material brush, then LEFT-DRAG in the cave. RIGHT-DRAG erases. The shallow front wall is generated from the exact rounded silhouette, so curves and mixed materials remain aligned.\"",
		"preview explanation"
	)
	text = _replace_once(
		text,
		"\t\tinstruction_label.text = \"Paint the complete downward-facing FRONT FACE for this material. It appears below exposed blocks in the mixed-material preview.\"",
		"\t\tinstruction_label.text = \"Paint a seamless FRONT SURFACE texture for this material. The generator clips and shades it inside the shallow extrusion derived from the exact rounded cave silhouette.\"",
		"front instruction"
	)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench UI")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Added generated extrusion controls and updated front-surface workflow text")
	get_tree().quit()
