extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"
const SAFE_ROOT := "res://tools/sprite_lab/safestates/front_column_radius_before_2026-07-20_1808"

func _write(path: String, text: String) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(path.get_base_dir())
	var mkdir_result := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_result != OK and mkdir_result != ERR_ALREADY_EXISTS:
		push_error("Could not create directory for " + path)
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing patch anchor: " + label)
		return ""
	return text.replace(old_value, new_value)

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	if preview.is_empty() or runtime.is_empty():
		push_error("Could not read extrusion scripts")
		get_tree().quit(1)
		return

	# Explicit restore point for this exact pre-change implementation.
	if not _write(SAFE_ROOT + "/tools/sprite_lab/dome_material_preview_v2.gd", preview):
		get_tree().quit(1)
		return
	if not _write(SAFE_ROOT + "/scripts/systems/world_generation/dome_front_extrusion_renderer.gd", runtime):
		get_tree().quit(1)
		return
	var manifest := {
		"name": "Front Column Radius Before Reduction",
		"created": "2026-07-20 18:08",
		"reason": "Restore point before reducing only the one-tile front-column radius.",
		"files": [PREVIEW_PATH, RUNTIME_PATH],
	}
	if not _write(SAFE_ROOT + "/SAFE_STATE_MANIFEST.json", JSON.stringify(manifest, "\t")):
		get_tree().quit(1)
		return

	var old_preview := '''\t\t\tvar mask_depth := mini(front_depth, 27)
\t\t\tvar mask_start_y := CELL_SIZE - mask_depth
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar local_y := CELL_SIZE + distance - 1
\t\t\t\tvar source_y := mask_start_y
\t\t\t\tif front_depth > 1 and mask_depth > 1:
\t\t\t\t\tsource_y += roundi(float(distance - 1) * float(mask_depth - 1) / float(front_depth - 1))
'''
	var new_preview := '''\t\t\tvar mask_depth := mini(front_depth, 27)
\t\t\tvar mask_start_y := CELL_SIZE - mask_depth
\t\t\tvar mask_end_y := CELL_SIZE - 1
\t\t\t# Front-extrusion-only exception: a one-tile column has LEFT, RIGHT and
\t\t\t# DOWN exposed (mask 14). Stop four logical source rows earlier so the
\t\t\t# lower sides converge less aggressively. Terrain/border masks are not
\t\t\t# modified; this affects only the generated front surface.
\t\t\tif mask == 14 and mask_start_y < CELL_SIZE - 5:
\t\t\t\tmask_end_y = CELL_SIZE - 5
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar local_y := CELL_SIZE + distance - 1
\t\t\t\tvar source_y := mask_start_y
\t\t\t\tif front_depth > 1 and mask_end_y > mask_start_y:
\t\t\t\t\tsource_y += roundi(float(distance - 1) * float(mask_end_y - mask_start_y) / float(front_depth - 1))
'''
	preview = _replace_once(preview, old_preview, new_preview, "preview column radius")
	if preview.is_empty() or not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var old_runtime := '''\tvar mask_depth := mini(depth, 27)
\tvar mask_start_y := TILE_SIZE - mask_depth
\tfor y in range(TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tvar shifted_y := y - depth
\t\t\tif y >= TILE_SIZE:
\t\t\t\tvar distance := y - TILE_SIZE
\t\t\t\tshifted_y = mask_start_y
\t\t\t\tif depth > 1 and mask_depth > 1:
\t\t\t\t\tshifted_y += roundi(float(distance) * float(mask_depth - 1) / float(depth - 1))
'''
	var new_runtime := '''\tvar mask_depth := mini(depth, 27)
\tvar mask_start_y := TILE_SIZE - mask_depth
\tvar mask_end_y := TILE_SIZE - 1
\t# Same front-only one-tile-column adjustment as the workbench. Runtime
\t# atlases are 64 px, so four logical pixels equal eight atlas pixels.
\tvar column_radius_reduction := maxi(1, roundi(float(TILE_SIZE) * 4.0 / 32.0))
\tif mask == 14 and mask_start_y < TILE_SIZE - 1 - column_radius_reduction:
\t\tmask_end_y = TILE_SIZE - 1 - column_radius_reduction
\tfor y in range(TILE_SIZE + depth):
\t\tfor x in range(TILE_SIZE):
\t\t\tvar shifted_y := y - depth
\t\t\tif y >= TILE_SIZE:
\t\t\t\tvar distance := y - TILE_SIZE
\t\t\t\tshifted_y = mask_start_y
\t\t\t\tif depth > 1 and mask_end_y > mask_start_y:
\t\t\t\t\tshifted_y += roundi(float(distance) * float(mask_end_y - mask_start_y) / float(depth - 1))
'''
	runtime = _replace_once(runtime, old_runtime, new_runtime, "runtime column radius")
	if runtime.is_empty() or not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return

	print("SHALLOWER_COLUMN_FRONT_RADIUS_APPLIED; SAFE_STATE=", SAFE_ROOT)
	get_tree().quit(0)
