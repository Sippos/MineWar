extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/golden_source_editor.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "\tvar sidebar_margin := MarginContainer.new()\n\tsidebar_margin.add_theme_constant_override(\"margin_left\", 10)\n\tsidebar_margin.add_theme_constant_override(\"margin_right\", 10)\n\tsidebar_margin.add_theme_constant_override(\"margin_top\", 9)\n\tsidebar_margin.add_theme_constant_override(\"margin_bottom\", 9)\n\tsidebar_panel.add_child(sidebar_margin)\n\n\tvar sidebar := VBoxContainer.new()\n\tsidebar.add_theme_constant_override(\"separation\", 6)\n\tsidebar_margin.add_child(sidebar)"
	var new_text := "\tvar sidebar_scroll := ScrollContainer.new()\n\tsidebar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tsidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL\n\tsidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED\n\tsidebar_panel.add_child(sidebar_scroll)\n\n\tvar sidebar_margin := MarginContainer.new()\n\tsidebar_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tsidebar_margin.add_theme_constant_override(\"margin_left\", 10)\n\tsidebar_margin.add_theme_constant_override(\"margin_right\", 10)\n\tsidebar_margin.add_theme_constant_override(\"margin_top\", 9)\n\tsidebar_margin.add_theme_constant_override(\"margin_bottom\", 9)\n\tsidebar_scroll.add_child(sidebar_margin)\n\n\tvar sidebar := VBoxContainer.new()\n\tsidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tsidebar.add_theme_constant_override(\"separation\", 6)\n\tsidebar_margin.add_child(sidebar)"
	if not source.contains(old_text):
		push_error("Sidebar patch anchor not found")
		get_tree().quit(1)
		return
	source = source.replace(old_text, new_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not patch terrain lab sidebar")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("PATCHED_TERRAIN_LAB_SIDEBAR")
	get_tree().quit(0)
