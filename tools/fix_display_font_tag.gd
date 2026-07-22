extends Node

const TARGET := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	var old_text := "font.variation_opentype = {TextServer.name_to_tag(\"wght\"): weight}"
	var new_text := "font.variation_opentype = {\"wght\": weight}"
	if source.count(old_text) != 1:
		push_error("Expected one display font tag target, found %d" % source.count(old_text))
		get_tree().quit(1)
		return
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % TARGET)
		get_tree().quit(1)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
	print("MINEWARS_DISPLAY_FONT_TAG_FIXED")
	get_tree().quit(0)
