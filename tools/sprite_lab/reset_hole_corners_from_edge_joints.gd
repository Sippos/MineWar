extends Node

const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const TIERS: Array[String] = ["unmineable", "easy", "medium", "hard"]
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14

func _ready() -> void:
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		push_error("Could not create source directory: %s" % error_string(directory_result))
		get_tree().quit(1)
		return

	for tier in TIERS:
		var joint_path := SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier
		if not FileAccess.file_exists(joint_path) and tier == "unmineable":
			joint_path = SOURCE_DIR + "/easy_edge_joint_top_left_32.png"
		if not FileAccess.file_exists(joint_path):
			push_error("Missing Edge Joint source for %s: %s" % [tier, joint_path])
			get_tree().quit(1)
			return

		var joint := Image.load_from_file(ProjectSettings.globalize_path(joint_path))
		if joint == null or joint.is_empty():
			push_error("Could not load Edge Joint source for %s" % tier)
			get_tree().quit(1)
			return
		joint.convert(Image.FORMAT_RGBA8)
		joint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

		# Rotate only the authored 14x14 patch. Rotating the complete 32x32 image
		# moves the artwork to the opposite quadrant and creates floating fragments.
		var hole_corner := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		hole_corner.fill(Color.TRANSPARENT)
		for y in range(PATCH_SIZE):
			for x in range(PATCH_SIZE):
				hole_corner.set_pixel(PATCH_SIZE - 1 - x, PATCH_SIZE - 1 - y, joint.get_pixel(x, y))

		var output_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		var save_result := hole_corner.save_png(output_path)
		if save_result != OK:
			push_error("Could not save Hole Corner for %s: %s" % [tier, error_string(save_result)])
			get_tree().quit(1)
			return

	print("Reset Hole Corners from the exact Edge Joint patch rotated 180 degrees")
	get_tree().quit()
