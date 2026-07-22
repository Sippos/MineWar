extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var old := "Each material has one straight border and one EDGE JOINT. HOLE CORNER is generated automatically as the exact solid/cave inverse of that Edge Joint and rotated four ways."
	var new := "Each material has one straight BORDER, one editable EDGE JOINT, and one editable opposite HOLE CORNER. Both corner workspaces use the same 14x14 painting workflow and rotate automatically four ways."
	if not text.contains(old):
		push_error("Could not find old Hole Corner help text")
		get_tree().quit(1)
		return
	text = text.replace(old, new)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Editable Hole Corner help text updated")
	get_tree().quit()
