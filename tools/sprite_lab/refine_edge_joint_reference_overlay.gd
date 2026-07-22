extends Node

const PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var old_value := '''func _make_convex_base(tier: String) -> Image:
	# Edge Joint transparency has two jobs: inside the top-left 14x14 core it
	# carves the silhouette, while outside that core it simply means no overlay.
	# A fully opaque reference tile made erasing Unmineable appear to do nothing.
	# Use a ghosted reference instead so transparent/erased pixels are obvious,
	# while the straight-border alignment remains visible underneath the artwork.
	var reference := CORNER_BUILDER.build_square_composite_tile(mass_image, border_images[tier], 1 | 8)
	reference.convert(Image.FORMAT_RGBA8)
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			var color := reference.get_pixel(x, y)
			color.a *= 0.22
			reference.set_pixel(x, y, color)
	for y in range(EDGE_JOINT_SIZE):
		for x in range(EDGE_JOINT_SIZE):
			# The destructive core previews the cave behind a transparent cutout,
			# but remains translucent enough that erased pixels show the checker.
			reference.set_pixel(x, y, Color(0.067, 0.09, 0.145, 0.55))
	return reference
'''
	var new_value := '''func _make_convex_base(tier: String) -> Image:
	# Show only a faint top/left alignment guide beneath the authored joint.
	# The old full-tile reference exposed mass decorations from other tiles and
	# looked like Easy/Medium/Unmineable artwork was leaking into each other.
	var reference := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	reference.fill(Color.TRANSPARENT)
	var top := (border_images[tier] as Image).duplicate()
	var left := CORNER_BUILDER.rotate_quarters(top, 3)
	for guide: Image in [top, left]:
		guide.convert(Image.FORMAT_RGBA8)
		for y in range(LOGICAL_SIZE):
			for x in range(LOGICAL_SIZE):
				var color := guide.get_pixel(x, y)
				color.a *= 0.24
				guide.set_pixel(x, y, color)
		reference.blend_rect(guide, Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i.ZERO)
	for y in range(EDGE_JOINT_SIZE):
		for x in range(EDGE_JOINT_SIZE):
			# Transparent pixels in this core are real silhouette cutouts.
			reference.set_pixel(x, y, Color(0.067, 0.09, 0.145, 0.48))
	return reference
'''
	if not text.contains(old_value):
		push_error("Missing Edge Joint reference function")
		get_tree().quit(1)
		return
	text = text.replace(old_value, new_value)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Edge Joint editor now uses isolated border guides only.")
	get_tree().quit()
