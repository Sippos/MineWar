extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14
const TIERS: Array[String] = ["easy", "medium", "hard", "unmineable"]

func _replace_function(text: String, function_name: String, next_function_name: String, replacement: String) -> String:
	var start := text.find("func %s(" % function_name)
	var finish := text.find("\nfunc %s(" % next_function_name, start)
	if start < 0 or finish < 0:
		push_error("Could not replace %s" % function_name)
		return ""
	return text.substr(0, start) + replacement + text.substr(finish)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)

	text = text.replace(
		"\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])",
		"\t\t# Hole Corner and Edge Joint are the same authored 14x14 source.\n\t\tcorner_images[tier] = convex_images[tier]"
	)

	var loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	# Compatibility helper: Hole Corner literally shares the Edge Joint source.
	return edge_joint
'''
	text = _replace_function(text, "_load_hole_corner_stamp", "_load_top_stamp", loader)
	if text.is_empty(): return false

	text = text.replace(
		'''\tif current_mode == "corner":
\t\treturn corner_images[tier]''',
		'''\tif current_mode == "corner":
\t\treturn convex_images[tier]'''
	)
	text = text.replace(
		'''\tif current_mode == "corner":
\t\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))''',
		'''\tif current_mode == "corner":
\t\treturn Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))'''
	)
	text = text.replace(
		"return \"%s HOLE CORNER • CENTERED VERTEX STAMP\" % current_tier.to_upper()",
		"return \"%s HOLE CORNER • SHARED EDGE JOINT\" % current_tier.to_upper()"
	)
	text = text.replace(
		'''\telif current_mode == "corner":
\t\tbase = _make_cave_base()''',
		'''\telif current_mode == "corner":
\t\tbase = _make_convex_base(visual_tier)'''
	)
	text = text.replace(
		"Paint one centered grid vertex. The starter in the bottom-right quadrant is an exact pixel-for-pixel copy of the Edge Joint curve at origin 16/16. Extend either border endpoint across the center when needed; preview and export rotate it four ways.",
		"Hole Corner uses the exact same 14x14 sprite as Edge Joint. Edit either workspace; preview and export rotate this shared patch into all four hole corners."
	)
	text = text.replace(
		"Each material has one straight BORDER, one editable EDGE JOINT, and one full 32x32 HOLE CORNER replacement stamp. The Hole Corner includes both border endpoints and rotates automatically four ways.",
		"Each material has one straight BORDER and one 14x14 EDGE JOINT source. HOLE CORNER reuses that exact sprite at the same native size and rotates it automatically four ways."
	)
	text = text.replace(
		'''\tif current_mode == "corner":
\t\tcorner_images[tier] = image''',
		'''\tif current_mode == "corner":
\t\tconvex_images[tier] = image
\t\tcorner_images[tier] = image'''
	)
	text = text.replace(
		"result = (corner_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)",
		"result = (convex_images[source_tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)"
	)
	text = text.replace(
		"var corner_atlas := _build_inside_corner_atlas(corner_images[source_tier])",
		"var corner_atlas := _build_inside_corner_atlas(convex_images[source_tier])"
	)
	text = text.replace(
		"Saved one mass, four borders, four edge joints and four editable hole corners.",
		"Saved one mass, four borders, and four shared Edge Joint/Hole Corner sources."
	)
	text = text.replace(
		"Exported four border atlases plus four Edge-Joint-derived Hole Corner atlases.",
		"Exported four border atlases plus four Hole Corner atlases from the shared Edge Joint source."
	)

	var exporter := '''func _build_inside_corner_atlas(edge_joint_source: Image) -> Image:
	# Use the exact native Edge Joint patch for Hole Corners. No 32x32 stamp,
	# scaling, reconstruction, or separate artwork is involved.
	var source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	source_patch.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			source_patch.set_pixel(x, y, edge_joint_source.get_pixel(x, y))

	var atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame in range(4):
		var rotated_patch := _rotate_export_corner_patch(source_patch, frame)
		var logical_tile := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		logical_tile.fill(Color.TRANSPARENT)
		var patch_position := Vector2i.ZERO
		match frame:
			1: patch_position = Vector2i(LOGICAL_SIZE - CORNER_PATCH_SIZE, 0)
			2: patch_position = Vector2i(LOGICAL_SIZE - CORNER_PATCH_SIZE, LOGICAL_SIZE - CORNER_PATCH_SIZE)
			3: patch_position = Vector2i(0, LOGICAL_SIZE - CORNER_PATCH_SIZE)
		logical_tile.blit_rect(rotated_patch, Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE)), patch_position)
		logical_tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(logical_tile, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(frame % 2, frame / 2) * TILE_SIZE)
	return atlas
'''
	text = _replace_function(text, "_build_inside_corner_atlas", "_rotate_export_corner_patch", exporter)
	if text.is_empty(): return false

	return _write(WORKBENCH_PATH, text)

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var builder := '''func _build_authored_corner_textures(edge_joint_source: Image) -> Array[ImageTexture]:
	# Hole Corner uses the same native 14x14 patch as Edge Joint.
	var source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	source_patch.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			source_patch.set_pixel(x, y, edge_joint_source.get_pixel(x, y))
	var result: Array[ImageTexture] = []
	for turn in range(4):
		result.append(ImageTexture.create_from_image(_rotate_corner_patch(source_patch, turn)))
	return result
'''
	text = _replace_function(text, "_build_authored_corner_textures", "_rotate_corner_patch", builder)
	if text.is_empty(): return false

	var rect_func := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# Native 14x14 patch placed directly in the matching corner of the empty cell.
	var patch_position := rect.position
	match frame:
		1: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.position.y)
		2: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.end.y - CORNER_PATCH_SIZE)
		3: patch_position = Vector2(rect.position.x, rect.end.y - CORNER_PATCH_SIZE)
	return Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''
	text = _replace_function(text, "_hole_corner_patch_rect", "_border_depth_for", rect_func)
	if text.is_empty(): return false
	return _write(PREVIEW_PATH, text)

func _patch_world() -> bool:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	var old := '''		# The 64x64 atlas frame is a vertex stamp. Position its center on the actual
		# grid intersection rather than on the empty-cell center.
		var frame_offset := Vector2(-32.0, -32.0)
		match frame:
			1:
				frame_offset = Vector2(32.0, -32.0)
			2:
				frame_offset = Vector2(32.0, 32.0)
			3:
				frame_offset = Vector2(-32.0, 32.0)
		var empty_center := block_layer.map_to_local(cell)
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(empty_center + frame_offset))
'''
	var replacement := '''		# Atlas frames are normal 64x64 empty-cell overlays containing one native
		# 14x14 shared Edge Joint patch in the appropriate corner.
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell)))
'''
	if not text.contains(old):
		push_error("Could not restore runtime empty-cell placement")
		return false
	text = text.replace(old, replacement)
	return _write(WORLD_PATH, text)

func _sync_sources() -> bool:
	for tier in TIERS:
		var source_tier := "easy" if tier == "unmineable" else tier
		var edge_path := SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % source_tier
		var hole_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		if not FileAccess.file_exists(edge_path):
			push_error("Missing %s" % edge_path)
			return false
		var edge := Image.load_from_file(ProjectSettings.globalize_path(edge_path))
		if edge == null or edge.is_empty():
			return false
		edge.convert(Image.FORMAT_RGBA8)
		edge.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
		if edge.save_png(hole_path) != OK:
			return false
	return true

func _ready() -> void:
	if not _patch_workbench() or not _patch_preview() or not _patch_world() or not _sync_sources():
		get_tree().quit(1)
		return
	print("Hole Corner now shares the exact native Edge Joint patch")
	get_tree().quit()
