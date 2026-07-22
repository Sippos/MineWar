extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/dome_material_workbench.gd"
	var text := FileAccess.get_file_as_string(path)
	var old_subtitle := "\tsubtitle.text = \"ONE dark mass tile  +  ONE top-border stamp per rock tier  →  automatic rotations and 16 masks\""
	var new_subtitle := "\tsubtitle.text = \"ONE dark mass tile  +  ONE border stamp per tier  →  rotations, rounded corners and interactive topology preview\""
	text = text.replace(old_subtitle, new_subtitle)
	var old_block := "\t_add_section(column, \"REAL-TIME LIVE PREVIEW\")\n\tvar explanation := Label.new()\n\texplanation.text = \"Paint one top border in the center. This preview rotates it to all four directions immediately. Cyan boxes mark exposed rock cells.\"\n\texplanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\texplanation.add_theme_font_size_override(\"font_size\", 10)\n\texplanation.add_theme_color_override(\"font_color\", Color.html(\"a7eaf5ff\"))\n\tcolumn.add_child(explanation)\n\tvar mode_selector := OptionButton.new()\n\tfor mode_name in [\"Wide room\", \"Vertical shaft\", \"Overhang / pillars\"]:\n\t\tmode_selector.add_item(mode_name)\n\tmode_selector.item_selected.connect(func(index: int) -> void: preview.call(\"set_preview_mode\", index))\n\tcolumn.add_child(mode_selector)\n\tvar center := CenterContainer.new()\n\tcenter.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tcenter.size_flags_vertical = Control.SIZE_EXPAND_FILL\n\tcolumn.add_child(center)\n\tpreview = PREVIEW_SCRIPT.new() as Control\n\tcenter.add_child(preview)"
	var new_block := "\t_add_section(column, \"INTERACTIVE LIVE CAVE\")\n\tvar explanation := Label.new()\n\texplanation.text = \"LEFT-DRAG removes blocks. RIGHT-DRAG restores them. Every edge and corner rebuilds immediately from the one border stamp.\"\n\texplanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\texplanation.add_theme_font_size_override(\"font_size\", 10)\n\texplanation.add_theme_color_override(\"font_color\", Color.html(\"a7eaf5ff\"))\n\tcolumn.add_child(explanation)\n\tvar option_row := HBoxContainer.new()\n\toption_row.add_theme_constant_override(\"separation\", 6)\n\tcolumn.add_child(option_row)\n\tvar mode_selector := OptionButton.new()\n\tmode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tfor mode_name in [\"Wide room\", \"Vertical shaft\", \"Overhang / pillars\"]:\n\t\tmode_selector.add_item(mode_name)\n\tmode_selector.item_selected.connect(func(index: int) -> void: preview.call(\"set_preview_mode\", index))\n\toption_row.add_child(mode_selector)\n\tvar reset_button := Button.new()\n\treset_button.text = \"Reset layout\"\n\treset_button.pressed.connect(func() -> void: preview.call(\"reset_current_template\"))\n\toption_row.add_child(reset_button)\n\tvar geometry_row := HBoxContainer.new()\n\tgeometry_row.add_theme_constant_override(\"separation\", 10)\n\tcolumn.add_child(geometry_row)\n\tvar round_toggle := CheckBox.new()\n\tround_toggle.text = \"Rounded light corners\"\n\tround_toggle.button_pressed = true\n\tround_toggle.toggled.connect(func(value: bool) -> void: preview.call(\"set_rounding_enabled\", value))\n\tgeometry_row.add_child(round_toggle)\n\tvar overhang_toggle := CheckBox.new()\n\toverhang_toggle.text = \"Rock lip outside cell\"\n\toverhang_toggle.button_pressed = true\n\toverhang_toggle.toggled.connect(func(value: bool) -> void: preview.call(\"set_overhang_enabled\", value))\n\tgeometry_row.add_child(overhang_toggle)\n\tvar center := CenterContainer.new()\n\tcenter.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tcenter.size_flags_vertical = Control.SIZE_EXPAND_FILL\n\tcolumn.add_child(center)\n\tpreview = PREVIEW_SCRIPT.new() as Control\n\tcenter.add_child(preview)"
	if not text.contains(old_block):
		push_error("Interactive preview UI anchor was not found")
		get_tree().quit(1)
		return
	text = text.replace(old_block, new_block)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write dome material workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Interactive cave preview UI installed")
	get_tree().quit()
