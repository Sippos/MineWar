extends Node

const PREVIEW = preload("res://tools/sprite_lab/safestates/dome_workbench_2_5d_locked_2026-07-20_1624/tools/sprite_lab/dome_material_preview_v2.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"

func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return image

func _ready() -> void:
	var preview := PREVIEW.new() as Control
	add_child(preview)
	await get_tree().process_frame
	var mass := _load(SOURCE_DIR + "/dark_mass_32.png")
	var borders := {}
	var corners := {}
	var joints := {}
	var fronts := {}
	for tier in ["unmineable", "easy", "medium", "hard"]:
		borders[tier] = _load(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		corners[tier] = _load(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		joints[tier] = _load(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		fronts[tier] = _load(SOURCE_DIR + "/%s_front_face_32.png" % tier)
	preview.call("set_material_library", mass, borders, corners, joints, fronts)
	preview.call("set_front_depth", 32)
	preview.call("_rebuild_extrusion_texture")
	var image := (preview.extrusion_texture as ImageTexture).get_image()
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	image.save_png("res://tools/sprite_lab/debug_front_masks/locked_preview_extrusion_32_scaled.png")
	get_tree().quit(0)
