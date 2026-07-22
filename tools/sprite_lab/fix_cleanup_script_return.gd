extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/cleanup_canonical_hole_preview.gd"
	var text := FileAccess.get_file_as_string(path)
	var old := "\t\ttext = text.substr(0, duplicate.x) + text.substr(duplicate.y + 1)\n\nfunc _ready() -> void:"
	var new := "\t\ttext = text.substr(0, duplicate.x) + text.substr(duplicate.y + 1)\n\treturn text\n\nfunc _ready() -> void:"
	if not text.contains(old):
		push_error("Cleanup return anchor missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text.replace(old, new))
	file.close()
	print("Fixed cleanup script return")
	get_tree().quit()
