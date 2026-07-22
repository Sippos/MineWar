extends Node

const PREVIEW := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const RUNTIME := preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")

func _ready() -> void:
	var preview := PREVIEW.new()
	var runtime := RUNTIME.new()
	# Top rows remain full width.
	assert(bool(preview.call("_front_face_mask_allows", 0, 0, 32, 10, true, false)))
	assert(bool(runtime.call("_front_face_mask_allows", 0, 0, 64, 10, true, false)))
	# Bottom outer tips are cut into a rounded profile.
	assert(not bool(preview.call("_front_face_mask_allows", 0, 9, 32, 10, true, false)))
	assert(not bool(runtime.call("_front_face_mask_allows", 0, 9, 64, 10, true, false)))
	# A tunnel join receives no rounding and therefore remains square.
	assert(bool(preview.call("_front_face_mask_allows", 0, 9, 32, 10, false, false)))
	assert(bool(runtime.call("_front_face_mask_allows", 0, 9, 64, 10, false, false)))
	print("Bottom front mask validated: outer tips round, tunnel joins stay square.")
	get_tree().quit()
