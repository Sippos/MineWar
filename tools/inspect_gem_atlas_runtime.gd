extends Node

func _ready() -> void:
	var image := Image.load_from_file("res://assets/sprites/world/terrain/gem_overlays/minewars_gem_overlay_atlas.png")
	var opaque := 0
	var transparent := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				opaque += 1
			else:
				transparent += 1
	print("GEM_ATLAS_ALPHA opaque=", opaque, " transparent=", transparent)
	get_tree().quit()
