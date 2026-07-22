extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_rounded := '''	if rounded_light_corners:
		selected_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, selected_border_image, selected_convex_image)
		unmineable_composite_textures = CORNER_BUILDER.build_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)'''
	var new_rounded := '''	if rounded_light_corners:
		selected_composite_textures = _build_logical_composite_textures(mass_image, selected_border_image, selected_convex_image)
		unmineable_composite_textures = _build_logical_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)'''
	if not text.contains(old_rounded):
		push_error("Could not find rounded preview texture block")
		get_tree().quit(1)
		return
	text = text.replace(old_rounded, new_rounded)

	var helper_anchor := "func _build_square_composite_textures(base: Image, top_border: Image) -> Array[ImageTexture]:"
	var helper := '''func _build_logical_composite_textures(base: Image, top_border: Image, edge_joint: Image) -> Array[ImageTexture]:
	# The live cave uses 32x32 cells. Keep solid tiles at their native logical
	# resolution so they use the same one-logical-pixel sampling as the 64x64
	# two-cell Hole Corner overlays. Upscaling to 64 and shrinking back to 32
	# introduces a half-texel sampling difference at the shared vertex.
	var result: Array[ImageTexture] = []
	for mask in range(16):
		var tile := CORNER_BUILDER.build_composite_tile(base, top_border, mask, edge_joint)
		result.append(ImageTexture.create_from_image(tile))
	return result

'''
	if not text.contains(helper_anchor):
		push_error("Could not find square preview helper anchor")
		get_tree().quit(1)
		return
	if not text.contains("func _build_logical_composite_textures("):
		text = text.replace(helper_anchor, helper + helper_anchor)

	var old_resize := '''		tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		result.append(ImageTexture.create_from_image(tile))'''
	var new_resize := '''		result.append(ImageTexture.create_from_image(tile))'''
	if not text.contains(old_resize):
		push_error("Could not find square preview resize")
		get_tree().quit(1)
		return
	text = text.replace(old_resize, new_resize)

	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview script")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Live cave solid tiles now render at native 32x32 logical scale")
	get_tree().quit()
