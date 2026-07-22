extends Node

const SNAPSHOT_ROOT := "res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624"
const CURRENT_PREVIEW := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const SAFE_PREVIEW := SNAPSHOT_ROOT + "/tools/sprite_lab/dome_material_preview_v2.gd"
const CURRENT_RUNTIME := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"
const SAFE_RUNTIME := SNAPSHOT_ROOT + "/scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _extract_function(text: String, name: String) -> String:
	var marker := "func %s(" % name
	var start := text.find(marker)
	if start < 0:
		return ""
	var next := text.find("\nfunc ", start + marker.length())
	if next < 0:
		next = text.length()
	return text.substr(start, next - start