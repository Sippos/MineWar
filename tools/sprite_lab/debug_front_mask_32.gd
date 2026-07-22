extends Node

const RENDERER = preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")
const ATLAS_PATH := "res://assets/sprites/world/terrain/dome/Easy_Border_Atlas.png"
const FRONT_PATH := "res://assets/sprites/world/terrain/dome/Easy_Front_Face.png"
const OUT_DIR := "res://tools/sprite_lab/debug_front_masks"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var renderer := RENDERER.new() as Node2D
	renderer.depth = 32
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	var front := Image.load_from_file(ProjectSettings.globalize_path(FRONT_PATH))
	atlas.convert(Image.FORMAT_RGBA8)
	front.convert(Image.FORMAT_RGBA8)
	front.resize(64, 64, Image.INTERPOLATE_NEAREST)
	renderer.atlas_images[1] = atlas
	renderer.front_images[1] = front
	for mask in [4, 6, 12, 14]:
		var image := renderer.call("_build_extrusion_image", 1, mask) as Image
		image.save_png(OUT_DIR + "/mask_%d_depth_32.png" % mask)
		var holes := 0
		for y in range(64, 96):
			for x in range(64):
				if image.get_pixel(x, y).a <= 0.05:
					holes += 1
		print("MASK=", mask, " FACE_HOLES=", holes)
	get_tree().quit(0)
