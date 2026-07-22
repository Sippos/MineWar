extends Node

const SNAPSHOT_ROOT := "res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624"
const FILES: Array[String] = [
	"res://tools/sprite_lab/dome_corner_builder.gd",
	"res://tools/sprite_lab/dome_material_canvas.gd",
	"res://tools/sprite_lab/dome_material_preview_v2.gd",
	"res://tools/sprite_lab/dome_material_workbench.gd",
	"res://tools/sprite_lab/dome_material_workbench.tscn",
	"res://tools/sprite_lab/export_dome_material_assets.gd",
	"res://tools/sprite_lab/export_dome_material_assets.tscn",
	"res://scripts/systems/world_generation/world.gd",
	"res://scripts/systems/world_generation/world_terrain_runtime.gd",
	"res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd",
	"res://scenes/world/mine/level.tscn",
]
const DIRECTORIES: Array[String] = [
	"res://tools/sprite_lab/source/dome_material",
	"res://assets/sprites/world/terrain/dome",
]

func _copy_file(source: String, destination: String) -> Error:
	var make_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	if make_result != OK and make_result != ERR_ALREADY_EXISTS:
		return make_result
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))

func _copy_directory(source_dir: String, destination_dir: String) -> Error:
	var make_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_dir))
	if make_result != OK and make_result != ERR_ALREADY_EXISTS:
		return make_result
	var directory := DirAccess.open(source_dir)
	if directory == null:
		return ERR_CANT_OPEN
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		var source_path := source_dir.path_join(name)
		var destination_path := destination_dir.path_join(name)
		var result := OK
		if directory.current_is_dir():
			result = _copy_directory(source_path, destination_path)
		else:
			result = _copy_file(source_path, destination_path)
		if result != OK:
			directory.list_dir_end()
			return result
	directory.list_dir_end()
	return OK

func _ready() -> void:
	var root_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_ROOT))
	if root_result != OK and root_result != ERR_ALREADY_EXISTS:
		push_error("Could not create safestate root: %s" % error_string(root_result))
		get_tree().quit(1)
		return
	for source in FILES:
		if not FileAccess.file_exists(source):
			push_error("Safestate source missing: %s" % source)
			get_tree().quit(1)
			return
		var result := _copy_file(source, SNAPSHOT_ROOT.path_join(source.trim_prefix("res://")))
		if result != OK:
			push_error("Could not copy %s: %s" % [source, error_string(result)])
			get_tree().quit(1)
			return
	for source_dir in DIRECTORIES:
		var result := _copy_directory(source_dir, SNAPSHOT_ROOT.path_join(source_dir.trim_prefix("res://")))
		if result != OK:
			push_error("Could not copy directory %s: %s" % [source_dir, error_string(result)])
			get_tree().quit(1)
			return
	var manifest := {
		"name": "Dome Workbench 2.5D Locked",
		"created": "2026-07-20 16:24",
		"reason": "User-approved authored borders, corners, independent materials and generated 2.5D front extrusion before full-width face correction.",
		"restore_note": "Copy files from this directory back to their matching res:// paths.",
		"files": FILES,
		"directories": DIRECTORIES,
	}
	var manifest_file := FileAccess.open(SNAPSHOT_ROOT.path_join("SAFE_STATE_MANIFEST.json"), FileAccess.WRITE)
	if manifest_file == null:
		push_error("Could not write safestate manifest")
		get_tree().quit(1)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t"))
	manifest_file.close()
	print("SAFE_STATE_LOCKED=", SNAPSHOT_ROOT)
	get_tree().quit(0)
