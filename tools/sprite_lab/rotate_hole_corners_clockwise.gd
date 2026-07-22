extends Node

const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const TIERS: Array[String] = ["unmineable", "easy", "medium", "hard"]
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14

func _ready() -> void:
	for tier in TIERS:
		var path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		if not FileAccess.file_exists(path):
			push_error("Missing Hole Corner source: %s" % path)
			get_tree().quit(1)
			return

		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		if source == null or source.is_empty():
			push_error("Could not load Hole Corner source: %s" % path)
			get_tree().quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		source.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

		# Rotate only the canonical 14x14 authored patch 90 degrees clockwise.
		# Everything outside the patch remains transparent to prevent fragments.
		var rotated := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		rotated.fill(Color.TRANSPARENT)
		for y in range(PATCH_SIZE):
			for x in range(PATCH_SIZE):
				rotated.set_pixel(PATCH_SIZE - 1 - y, x, source.get_pixel(x, y))

		var result := rotated.save_png(path)
		if result != OK:
			push_error("Could not save rotated Hole Corner for %s: %s" % [tier, error_string(result)])
			get_tree().quit(1)
			return

	print("Rotated all Hole Corner sources 90 degrees clockwise")
	get_tree().quit()
