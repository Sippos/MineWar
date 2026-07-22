extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _patch_file(path: String, replacements: Array[Array]) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read " + path)
		return false
	for replacement in replacements:
		text = _replace_once(text, String(replacement[0]), String(replacement[1]), String(replacement[2]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var ok := true
	ok = _patch_file(WORKBENCH_PATH, [
		["\tdepth_slider.max_value = 16", "\tdepth_slider.max_value = 32", "workbench slider maximum"],
	]) and ok
	ok = _patch_file(PREVIEW_PATH, [
		["\tfront_depth = clampi(value, 2, 16)", "\tfront_depth = clampi(value, 2, 32)", "preview depth clamp"],
	]) and ok
	ok = _patch_file(RUNTIME_PATH, [
		["\tdepth = clampi(extrusion_depth, 2, 20)", "\tdepth = clampi(extrusion_depth, 2, 32)", "runtime depth clamp"],
	]) and ok
	if ok:
		print("Front extrusion depth range extended to 32 pixels")
	get_tree().quit(0 if ok else 1)
