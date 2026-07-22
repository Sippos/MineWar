extends Node

const PREVIEW_SCRIPT := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const RUNTIME_SCRIPT := preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const DOME_DIR := "res://assets/sprites/world/terrain/dome"

func _load_image(path: String, size: int = 32) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_error("Missing test image: " + path)
		return Image.new()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size, size, Image.INTERPOLATE_NEAREST)
	return image

func _ready() -> void:
	var preview := PREVIEW_SCRIPT.new() as Control
	add_child(preview)
	await get_tree().process_frame

	var mass := _load_image(SOURCE_DIR + "/dark_mass_32.png")
	var border := _load_image(SOURCE_DIR + "/easy_border_top_32.png")
	var joint := _load_image(SOURCE_DIR + "/easy_edge_joint_top_left_32.png")
	var corner := _load_image(SOURCE_DIR + "/easy_hole_corner_top_left_32.png")
	var front := _load_image(SOURCE_DIR + "/easy_front_face_32.png")
	var borders := {}
	var joints := {}
	var corners := {}
	var fronts := {}
	for tier in ["unmineable", "easy", "medium", "hard"]:
		borders[tier] = border
		joints[tier] = joint
		corners[tier] = corner
		fronts[tier] = front
	preview.call("set_material_library", mass, borders, corners, joints, fronts)
	preview.cells.clear()
	for y in range(8):
		for x in range(12):
			preview.cells[Vector2i(x, y)] = 0
	preview.cells[Vector2i(5, 3)] = 2
	preview.call("set_front_depth", 32)
	preview.call("_rebuild_extrusion_texture")
	var preview_image := (preview.extrusion_texture as ImageTexture).get_image()
	for distance in range(32):
		var y := 4 * 32 + distance
		for x in range(5 * 32, 6 * 32):
			if preview_image.get_pixel(x, y).a <= 0.95:
				push_error("Preview face is not full width at %d,%d" % [x, y])
				get_tree().quit(1)
				return

	var renderer := RUNTIME_SCRIPT.new() as Node2D
	renderer.depth = 32
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(DOME_DIR + "/Easy_Border_Atlas.png"))
	atlas.convert(Image.FORMAT_RGBA8)
	var runtime_front := Image.load_from_file(ProjectSettings.globalize_path(DOME_DIR + "/Easy_Front_Face.png"))
	runtime_front.convert(Image.FORMAT_RGBA8)
	runtime_front.resize(64, 64, Image.INTERPOLATE_NEAREST)
	renderer.atlas_images[1] = atlas
	renderer.front_images[1] = runtime_front
	# Bottom + left exposure forces the old rounded side curve into the face area.
	var runtime_image := renderer.call("_build_extrusion_image", 1, 4 | 8) as Image
	for distance in range(32):
		var y := 64 + distance
		for x in range(64):
			if runtime_image.get_pixel(x, y).a <= 0.95:
				push_error("Runtime face is not full width at %d,%d" % [x, y])
				get_tree().quit(1)
				return
	print("PASS: front faces remain complete width despite side-border curves")
	get_tree().quit(0)
