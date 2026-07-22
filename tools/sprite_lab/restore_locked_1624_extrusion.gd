extends Node

const SNAPSHOT_ROOT := "res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624"
const COPIES := {
	SNAPSHOT_ROOT + "/tools/sprite_lab/dome_material_preview_v2.gd": "res://tools/sprite_lab/dome_material_preview_v2.gd",
	SNAPSHOT_ROOT + "/scripts/systems/world_generation/dome_front_extrusion_renderer.gd": "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd",
}

func _copy_text(source: String, destination: String) -> Error:
	if not FileAccess.file_exists(source):
		return ERR_FILE_NOT_FOUND
	var content := FileAccess.get_file_as_string(source)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.close()
	return OK

func _ready() -> void:
	for source_value: Variant in COPIES.keys():
		var source := String(source_value)
		var destination := String(COPIES[source])
		var result := _copy_text(source, destination)
		if result != OK:
			push_error("Could not restore %s: %s" % [destination, error_string(result)])
			get_tree().quit(1)
			return
	print("RESTORED_LOCKED_1624_EXTRUSION")
	get_tree().quit(0)
