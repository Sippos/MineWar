extends Node

const PREVIEW_SCRIPT := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const DEPTH := 27

func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_error("Missing test image: " + path)
		return Image.new()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return image

func _ready() -> void:
	var preview := PREVIEW_SCRIPT.new() as Control
	add_child(preview)
	await get_tree().process_frame

	var mass := _load_image(SOURCE_DIR + "/dark_mass_32.png")
	var borders := {}
	var corners := {}
	var joints := {}
	var fronts := {}
	for tier in ["unmineable", "easy", "medium", "hard"]:
		borders[tier] = _load_image(SOURCE_DIR + "/%s_border_top_32.png" % tier)
		corners[tier] = _load_image(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		joints[tier] = _load_image(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier)
		fronts[tier] = _load_image(SOURCE_DIR + "/%s_front_face_32.png" % tier)
	preview.call("set_material_library", mass, borders, corners, joints, fronts)
	preview.call("set_front_depth", DEPTH)
	preview.call("reset_layout")
	preview.call("_rebuild_extrusion_texture")

	var output := (preview.extrusion_texture as ImageTexture).get_image()
	var tested_faces := 0
	for cell_y in range(8):
		for cell_x in range(12):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := int(preview.call("_cell_type", cell))
			if owner_type == 0 or bool(preview.call("_is_solid", cell + Vector2i.DOWN)):
				continue
			var mask := int(preview.call("_exposure_mask", cell))
			var tier := String(preview.call("_tier_for_cell_type", owner_type))
			var images := preview.composite_images[tier] as Array
			var tile := images[mask] as Image
			for distance in range(1, DEPTH + 1):
				var source_y := 32 + distance - 1 - DEPTH
				var world_y := cell_y * 32 + 32 + distance - 1
				for local_x in range(32):
					var world_x := cell_x * 32 + local_x
					var expected := tile.get_pixel(local_x, source_y).a > 0.05
					var actual := output.get_pixel(world_x, world_y).a > 0.05
					if actual != expected:
						push_error("Ownership mismatch cell=%s local=(%d,%d) expected=%s actual=%s" % [str(cell), local_x, distance - 1, str(expected), str(actual)])
						get_tree().quit(1)
						return
			tested_faces += 1
	if tested_faces == 0:
		push_error("No downward faces were tested")
		get_tree().quit(1)
		return
	print("PASS: locked 16:24 mask preserved exactly at 27 px; side-wall overlap removed for %d faces" % tested_faces)
	get_tree().quit(0)
