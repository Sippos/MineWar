extends Node

func _ready() -> void:
	var path := "res://tools/apply_immersive_ux_pass.gd"
	var source := FileAccess.get_file_as_string(path)
	var old := "_replace_function(path, \"func _create_first_run_stronghold_guide() -> void:\""
	var new := "_replace_function(path, \"func _create_first_run_stronghold_cue() -> void:\""
	if not source.contains(old):
		push_error("Immersive patch signature target missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source.replace(old, new))
	file.close()
	print("IMMERSIVE_PATCH_SCRIPT_FIXED")
	get_tree().quit(0)
