extends Node

const SAFE_ROOT := "res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624/"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const SAFE_WORKBENCH_PATH := SAFE_ROOT + "tools/sprite_lab/dome_material_workbench.gd"
const SAFE_PREVIEW_PATH := SAFE_ROOT + "tools/sprite_lab/dome_material_preview_v2.gd"

func _extract_function(text: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := text.find(marker)
	if start < 0:
		push_error("Missing source function: " + function_name)
		return ""
	var finish := text.find("\nfunc ", start + marker.length())
	if finish < 0:
		finish = text.length()
	return text.substr(start, finish - start)

func _replace_function(text: String, function_name: String, replacement: String) -> String:
	var marker := "func %s(" % function_name
	var start := text.find(marker)
	if start < 0:
		push_error("Missing destination function: " + function_name)
		return text
	var finish := text.find("\nfunc ", start + marker.length())
	if finish < 0:
		finish = text.length()
	return text.substr(0, start) + replacement + text.substr(finish)

func _ready() -> void:
	var workbench := FileAccess.get_file_as_string(WORKBENCH_PATH)
	var safe_workbench := FileAccess.get_file_as_string(SAFE_WORKBENCH_PATH)
	var safe_refresh := _extract_function(safe_workbench, "_refresh_workspace")
	if safe_refresh.is_empty():
		get_tree().quit(1)
		return
	workbench = _replace_function(workbench, "_refresh_workspace", safe_refresh)
	var error := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if error == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	error.store_string(workbench)
	error.close()

	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var safe_preview := FileAccess.get_file_as_string(SAFE_PREVIEW_PATH)
	var safe_bands := _extract_function(safe_preview, "_restore_hole_corner_border_bands")
	if safe_bands.is_empty():
		get_tree().quit(1)
		return
	preview = _replace_function(preview, "_restore_hole_corner_border_bands", safe_bands)
	var preview_file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if preview_file == null:
		push_error("Could not write preview")
		get_tree().quit(1)
		return
	preview_file.store_string(preview)
	preview_file.close()

	print("REVERTED_BAD_LIVE_CORNER_COUPLING")
	get_tree().quit(0)
