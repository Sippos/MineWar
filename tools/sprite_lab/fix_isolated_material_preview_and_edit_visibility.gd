extends Node

const WORKBENCH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW := "res://tools/sprite_lab/dome_material_preview_v2.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing patch anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var workbench := FileAccess.get_file_as_string(WORKBENCH)
	var old_base := '''func _make_convex_base(tier: String) -> Image:
	var image := CORNER_BUILDER.build_square_composite_tile(mass_image, border_images[tier], 1 | 8)
	for y in range(14):
		for x in range(14):
			image.set_pixel(x, y, Color.html("111725ff"))
	return image
'''
	var new_base := '''func _make_convex_base(tier: String) -> Image:
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
	workbench = _replace_once(workbench, old_base, new_base, "ghosted Edge Joint reference")
	workbench = workbench.replace(
		"Paint the EDGE JOINT on the full 32x32 overscan tile. The original top-left 14x14 area remains the safe silhouette-cutout core; opaque details and curve continuation may extend across the rest of the tile.",
		"Paint the EDGE JOINT on the full 32x32 overscan tile. The top-left 14x14 area is the silhouette-cutout core; the faint tile beneath is reference only, so erased pixels remain clearly visible."
	)
	if not _write(WORKBENCH, workbench):
		get_tree().quit(1)
		return

	var preview := FileAccess.get_file_as_string(PREVIEW)
	var old_reset := '''func reset_layout() -> void:
	cells.clear()
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			cells[cell] = CellType.UNMINEABLE if _is_outer_ring(cell) else CellType.EASY
	for y in range(2, 6):
		for x in range(2, 10):
			cells[Vector2i(x, y)] = CellType.EMPTY
	# Mixed comparison shelf with an exposed curved underside.
	cells[Vector2i(4, 4)] = CellType.EASY
	cells[Vector2i(5, 4)] = CellType.MEDIUM
	cells[Vector2i(6, 4)] = CellType.HARD
	cells[Vector2i(3, 2)] = CellType.MEDIUM
	cells[Vector2i(8, 2)] = CellType.HARD
	_mark_extrusion_dirty()
'''
	var new_reset := '''func reset_layout() -> void:
	cells.clear()
	# Every default solid uses the PRIMARY preview slot. The selected material
	# therefore owns the complete test cave, including its outer ring. Previously
	# the fixed Unmineable ring overlaid its corners while Easy/Medium/Hard were
	# being authored, which looked like cross-material editing interference.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			cells[Vector2i(x, y)] = CellType.EASY
	for y in range(2, 6):
		for x in range(2, 10):
			cells[Vector2i(x, y)] = CellType.EMPTY
	# One isolated shelf keeps the front-face and bottom-mask cases visible, but
	# it also uses the primary slot. Different materials only appear when the
	# artist explicitly paints them with a preview brush.
	cells[Vector2i(4, 4)] = CellType.EASY
	cells[Vector2i(5, 4)] = CellType.EASY
	cells[Vector2i(6, 4)] = CellType.EASY
	cells[Vector2i(3, 2)] = CellType.EASY
	cells[Vector2i(8, 2)] = CellType.EASY
	_mark_extrusion_dirty()
'''
	preview = _replace_once(preview, old_reset, new_reset, "isolated selected-material preview")
	if not _write(PREVIEW, preview):
		get_tree().quit(1)
		return

	print("Material previews isolated; Unmineable Edge Joint erasing is now visible.")
	get_tree().quit()
