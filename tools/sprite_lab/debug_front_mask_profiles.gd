extends Node

const RENDERER = preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")
const ATLAS_PATH := "res://assets/sprites/world/terrain/dome/Easy_Border_Atlas.png"
const FRONT_PATH := "res://assets/sprites/world/terrain/dome/Easy_Front_Face.png"

func _ready() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	var front := Image.load_from_file(ProjectSettings.globalize_path(FRONT_PATH))
	atlas.convert(Image.FORMAT_RGBA8)
	front.convert(Image.FORMAT_RGBA8)
	front.resize(64, 64, Image.INTERPOLATE_NEAREST)
	for depth_value in [16, 27, 32]:
		var renderer := RENDERER.new() as Node2D
		renderer.depth = depth_value
		renderer.atlas_images[1] = atlas
		renderer.front_images[1] = front
		var image := renderer.call("_build_extrusion_image", 1, 6) as Image
		print("DEPTH=", depth_value)
		for distance in range(depth_value):
			var y := 64 + distance
			var min_x := 999
			var max_x := -1
			for x in range(64):
				if image.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
			print("ROW ", distance, " MIN=", min_x, " MAX=", max_x, " WIDTH=", maxi(0, max_x - min_x + 1))
	get_tree().quit(0)
