extends Node

const SAFE_ROOT := "res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"
const SAFE_PREVIEW_PATH := SAFE_ROOT + "/tools/sprite_lab/dome_material_preview_v2.gd"
const SAFE_RUNTIME_PATH := SAFE_ROOT + "/scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path,