extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const LOGICAL_SIZE := 32
const OLD_PATCH_SIZE := 14
const OLD_ORIGIN := Vector2i(LOGICAL_SIZE - OLD_PATCH_SIZE, LOGICAL_SIZE - OLD_PATCH_SIZE)
const TIERS: Array[String] = ["easy", "medium", "hard", "unmineable"]

func _replace_once(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

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

	var old_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	# Hole Corner is authored on the BOTTOM-RIGHT corner of the diagonal dirt tile.
	# Older sources stored the same 14x14 patch at top-left; migrate them in memory.
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var source: Image
	if FileAccess.file_exists(editable_path):
		source = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
	else:
		source = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
	source.convert(Image.FORMAT_RGBA8)
	source.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var bottom_right_alpha := 0
	var top_left_alpha := 0
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			if source.get_pixel(HOLE_CORNER_ORIGIN.x + x, HOLE_CORNER_ORIGIN.y + y).a > 0.05:
				bottom_right_alpha += 1
			if source.get_pixel(x, y).a > 0.05:
				top_left_alpha += 1
	var source_origin := HOLE_CORNER_ORIGIN if bottom_right_alpha >= top_left_alpha and bottom_right_alpha > 0 else Vector2i.ZERO
	var clean := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	clean.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			clean.set_pixel(HOLE_CORNER_ORIGIN.x + x, HOLE_CORNER_ORIGIN.y + y, source.get_pixel(source_origin.x + x, source_origin.y + y))
	return clean
'''
	var new_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	# Hole Corner is a complete 32x32 replacement stamp for the EMPTY cell.
	# The full canvas is editable so both straight-border endpoints and the curve
	# can be authored together without hidden neighbouring-tile pixels.
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var source: Image
	if FileAccess.file_exists(editable_path):
		source = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
	else:
		source = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		source.fill(Color.TRANSPARENT)
	source.convert(Image.FORMAT_RGBA8)
	source.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return source
'''
	text = _replace_once(text, old_loader, new_loader, "full-cell Hole Corner loader")
	if text.is_empty(): return false

	text = _replace_once(text,
		'''\tif current_mode == "corner":
\t\treturn Rect2i(HOLE_CORNER_ORIGIN, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))''',
		'''\tif current_mode == "corner":
\t\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))''',
		"full Hole Corner active region")
	if text.is_empty(): return false

	text = _replace_once(text,
		'''\tif current_mode == "corner":
\t\treturn "%s HOLE CORNER • EDIT BOTTOM-RIGHT DIRT CORNER" % current_tier.to_upper()''',
		'''\tif current_mode == "corner":
\t\treturn "%s HOLE CORNER • EDIT FULL 32x32 VERTEX STAMP" % current_tier.to_upper()''',
		"Hole Corner title")
	if text.is_empty(): return false

	var old_base := '''func _make_cave_base() -> Image:
	# Show the full diagonal dirt tile. Only its bottom-right authored corner uses
	# cave colour beneath transparent pixels, so painting happens ON THE DIRT rim.
	var image := mass_image.duplicate()
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			image.set_pixel(HOLE_CORNER_ORIGIN.x + x, HOLE_CORNER_ORIGIN.y + y, Color.html("111725ff"))
	return image
'''
	var new_base := '''func _make_cave_base() -> Image:
	# The Hole Corner stamp replaces an EMPTY cell, so transparent pixels reveal
	# cave space. All authored border endpoints and the rounded join are painted
	# directly on this complete 32x32 canvas.
	var image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.html("111725ff"))
	return image
'''
	text = _replace_once(text, old_base, new_base, "full-cell cave base")
	if text.is_empty(): return false

	text = _replace_once(text,
		"Paint the BOTTOM-RIGHT corner of this full dirt tile. The dark area is cave space; paint the curved rim on the surrounding dirt. Export rotates this dirt-corner patch into all four directions.",
		"Paint the complete 32x32 HOLE CORNER replacement stamp. Draw both straight-border endpoints and their rounded connection directly on the cave background. Export rotates the complete stamp into all four directions.",
		"Hole Corner instructions")
	if text.is_empty(): return false

	text = _replace_once(text,
		"Each material has one straight BORDER, one editable EDGE JOINT, and one editable opposite HOLE CORNER. Both corner workspaces use the same 14x14 painting workflow and rotate automatically four ways.",
		"Each material has one straight BORDER, one editable EDGE JOINT, and one full 32x32 HOLE CORNER replacement stamp. The Hole Corner includes both border endpoints and rotates automatically four ways.",
		"tier note")
	if text.is_empty(): return false

	var export_start := text.find("func _build_inside_corner_atlas(")
	var export_end := text.find("\nfunc _rotate_export_corner_patch", export_start)
	if export_start < 0 or export_end < 0:
		push_error("Could not locate inside-corner exporter")
		return false
	var export_replacement := '''func _build_inside_corner_atlas(source_stamp: Image) -> Image:
	var atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame in range(4):
		var logical_tile := CORNER_BUILDER.rotate_quarters(source_stamp, frame)
		logical_tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(logical_tile, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(frame % 2, frame / 2) * TILE_SIZE)
	return atlas
'''
	text = text.substr(0, export_start) + export_replacement + text.substr(export_end)

	return _write(WORKBENCH_PATH, text)

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var build_start := text.find("func _build_authored_corner_textures(")
	var build_end := text.find("\nfunc _rotate_corner_patch", build_start)
	if build_start < 0 or build_end < 0:
		push_error("Could not locate preview corner texture builder")
		return false
	var replacement := '''func _build_authored_corner_textures(source_stamp: Image) -> Array[ImageTexture]:
	var result: Array[ImageTexture] = []
	for turn in range(4):
		var corner := CORNER_BUILDER.rotate_quarters(source_stamp, turn)
		result.append(ImageTexture.create_from_image(corner))
	return result
'''
	text = text.substr(0, build_start) + replacement + text.substr(build_end)

	var rect_start := text.find("func _hole_corner_patch_rect(")
	var rect_end := text.find("\nfunc _border_depth_for", rect_start)
	if rect_start < 0 or rect_end < 0:
		push_error("Could not locate preview corner rect")
		return false
	var rect_replacement := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# Full-cell replacement stamp: the frame exactly covers the empty cell.
	return rect
'''
	text = text.substr(0, rect_start) + rect_replacement + text.substr(rect_end)
	return _write(PREVIEW_PATH, text)

func _migrate_sources() -> bool:
	for tier in TIERS:
		var path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		if not FileAccess.file_exists(path):
			continue
		var old := Image.load_from_file(ProjectSettings.globalize_path(path))
		if old == null or old.is_empty():
			continue
		old.convert(Image.FORMAT_RGBA8)
		old.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
		# Keep all existing pixels exactly where they currently are. The important
		# migration is that the whole image is now editable/exported instead of only
		# the old bottom-right 14x14 crop.
		var result := old.save_png(path)
		if result != OK:
			push_error("Could not migrate %s" % path)
			return false
	return true

func _ready() -> void:
	if not _patch_workbench() or not _patch_preview() or not _migrate_sources():
		get_tree().quit(1)
		return
	print("Hole Corner converted to full 32x32 replacement stamps")
	get_tree().quit()
