extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/tile_workspace_editor.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("\t_update_help_text()\n\n\tvar gem_visible", "\t_update_help_text()\n\t_update_usage_text()\n\n\tvar gem_visible")
	var anchor := "func _compose_selected_tile() -> Image:\n"
	var insert := "func _update_usage_text() -> void:\n\tmatch _focus_component():\n\t\t\"mass\": usage_label.text = \"Cyan boxes mark every mineable solid block using this dark mass texture.\"\n\t\t\"top\": usage_label.text = \"Cyan boxes mark solid blocks with DUG SPACE ABOVE. The top-edge sprite is drawn there.\"\n\t\t\"right\": usage_label.text = \"Cyan boxes mark solid blocks with DUG SPACE TO THE RIGHT. The right-edge sprite is drawn there.\"\n\t\t\"bottom\": usage_label.text = \"Cyan boxes mark solid blocks with DUG SPACE BELOW. This is the thicker bottom/front rim—no projected second tile.\"\n\t\t\"left\": usage_label.text = \"Cyan boxes mark solid blocks with DUG SPACE TO THE LEFT. The left-edge sprite is drawn there.\"\n\t\t\"bedrock\": usage_label.text = \"Cyan boxes mark the full-color, unmineable ring around the playable mine.\"\n\t\t\"gem\": usage_label.text = \"The cyan example tile shows where this transparent embedded gem overlay is composed with dirt and an exposed rim.\"\n\n"
	if not text.contains(anchor):
		push_error("Workspace usage patch anchor missing")
		get_tree().quit(1)
		return
	text = text.replace(anchor, insert + anchor)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workspace usage patch")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Workspace direction usage labels installed")
	get_tree().quit()
