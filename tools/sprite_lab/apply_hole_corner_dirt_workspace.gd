extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const CANVAS_PATH := "res://tools/sprite_lab/dome_material_canvas.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const LOGICAL_SIZE := 32
const PATCH_SIZE := 14
const PATCH_ORIGIN := Vector2i(LOGICAL_SIZE - PATCH_SIZE, LOGICAL_SIZE - PATCH_SIZE)
const TIERS: Array[String] = ["easy", "medium", "hard", "unmineable"]

func _replace_once(text: String, old: String, new: String, label: String) -> String:
	if not text.contains(old):
		push_error("Could not find patch target: %s" % label)
		return ""
	return text.replace(old, new)

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
	text = _replace_once(
		text,
		"const LOGICAL_SIZE := 32\nconst TILE_SIZE := 64",
		"const LOGICAL_SIZE := 32\nconst CORNER_PATCH_SIZE := 14\nconst HOLE_CORNER_ORIGIN := Vector2i(LOGICAL_SIZE - CORNER_PATCH_SIZE, LOGICAL_SIZE - CORNER_PATCH_SIZE)\nconst TILE_SIZE := 64",
		"workbench constants"
	)
	if text.is_empty(): return false

	var old_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var corner: Image
	if FileAccess.file_exists(editable_path):
		corner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
	else:
		# First-time starter only: use the exact Edge Joint in the opposite orientation.
		corner = CORNER_BUILDER.rotate_quarters(edge_joint, 2)
	corner.convert(Image.FORMAT_RGBA8)
	corner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return corner
'''
	var new_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
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
	text = _replace_once(text, old_loader, new_loader, "Hole Corner loader")
	if text.is_empty(): return false

	var old_region := '''func _active_region() -> Rect2i:
	if current_mode == "mass":
		return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
	if current_mode == "corner" or current_mode == "convex":
		return Rect2i(Vector2i.ZERO, Vector2i(14, 14))
	return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))
'''
	var new_region := '''func _active_region() -> Rect2i:
	if current_mode == "mass":
		return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))
	if current_mode == "corner":
		return Rect2i(HOLE_CORNER_ORIGIN, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
	if current_mode == "convex":
		return Rect2i(Vector2i.ZERO, Vector2i(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
	return Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))
'''
	text = _replace_once(text, old_region, new_region, "active region")
	if text.is_empty(): return false

	text = _replace_once(
		text,
		"return \"%s HOLE CORNER • EDIT TOP-LEFT ONLY\" % current_tier.to_upper()",
		"return \"%s HOLE CORNER • EDIT BOTTOM-RIGHT DIRT CORNER\" % current_tier.to_upper()",
		"Hole Corner title"
	)
	if text.is_empty(): return false

	var old_base := '''func _make_cave_base() -> Image:
	# Base for the Hole Corner replacement patch: normal dark mass outside the
	# authored corner and cave colour beneath transparent cutout pixels.
	var image := mass_image.duplicate()
	for y in range(14):
		for x in range(14):
			image.set_pixel(x, y, Color.html("111725ff"))
	return image
'''
	var new_base := '''func _make_cave_base() -> Image:
	# Show the full diagonal dirt tile. Only its bottom-right authored corner uses
	# cave colour beneath transparent pixels, so painting happens ON THE DIRT rim.
	var image := mass_image.duplicate()
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			image.set_pixel(HOLE_CORNER_ORIGIN.x + x, HOLE_CORNER_ORIGIN.y + y, Color.html("111725ff"))
	return image
'''
	text = _replace_once(text, old_base, new_base, "Hole Corner base")
	if text.is_empty(): return false

	text = _replace_once(
		text,
		"Paint the TOP-LEFT HOLE CORNER directly, exactly like Edge Joint. It started as the opposite/inverted turn and rotates automatically into all four directions.",
		"Paint the BOTTOM-RIGHT corner of this full dirt tile. The dark area is cave space; paint the curved rim on the surrounding dirt. Export rotates this dirt-corner patch into all four directions.",
		"Hole Corner instructions"
	)
	if text.is_empty(): return false

	# Runtime atlas extraction now reads the bottom-right authored dirt patch.
	text = _replace_once(
		text,
		"source_patch.set_pixel(x, y, top_left_corner.get_pixel(x, y))",
		"source_patch.set_pixel(x, y, top_left_corner.get_pixel(HOLE_CORNER_ORIGIN.x + x, HOLE_CORNER_ORIGIN.y + y))",
		"export extraction"
	)
	if text.is_empty(): return false

	return _write(WORKBENCH_PATH, text)

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_once(
		text,
		"const CORNER_PATCH_SIZE := 14",
		"const CORNER_PATCH_SIZE := 14\nconst HOLE_CORNER_ORIGIN := Vector2i(LOGICAL_SIZE - CORNER_PATCH_SIZE, LOGICAL_SIZE - CORNER_PATCH_SIZE)",
		"preview origin constant"
	)
	if text.is_empty(): return false
	text = _replace_once(
		text,
		"source_patch.set_pixel(x, y, top_left_corner.get_pixel(x, y))",
		"source_patch.set_pixel(x, y, top_left_corner.get_pixel(HOLE_CORNER_ORIGIN.x + x, HOLE_CORNER_ORIGIN.y + y))",
		"preview extraction"
	)
	if text.is_empty(): return false
	return _write(PREVIEW_PATH, text)

func _patch_canvas() -> bool:
	var text := FileAccess.get_file_as_string(CANVAS_PATH)
	text = _replace_once(
		text,
		'''func _focus_region() -> bool:
	# Corner and edge-joint sources are intentionally small. Zoom them to the
	# complete canvas so the user never accidentally paints in a locked area.
	return edit_region.size.x <= 16 and edit_region.size.y <= 16
''',
		'''func _focus_region() -> bool:
	# Edge Joint is a top-left patch and benefits from zoom. Hole Corner lives at
	# bottom-right of a full dirt tile, so keep the whole 32x32 tile visible.
	return edit_region.position == Vector2i.ZERO and edit_region.size.x <= 16 and edit_region.size.y <= 16
''',
		"canvas focus rule"
	)
	if text.is_empty(): return false
	return _write(CANVAS_PATH, text)

func _migrate_sources() -> bool:
	for tier in TIERS:
		var path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		if not FileAccess.file_exists(path):
			continue
		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		if source == null or source.is_empty():
			push_error("Could not load %s" % path)
			return false
		source.convert(Image.FORMAT_RGBA8)
		source.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
		var top_count := 0
		var bottom_count := 0
		for y in range(PATCH_SIZE):
			for x in range(PATCH_SIZE):
				if source.get_pixel(x, y).a > 0.05: top_count += 1
				if source.get_pixel(PATCH_ORIGIN.x + x, PATCH_ORIGIN.y + y).a > 0.05: bottom_count += 1
		var origin := PATCH_ORIGIN if bottom_count >= top_count and bottom_count > 0 else Vector2i.ZERO
		var migrated := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		migrated.fill(Color.TRANSPARENT)
		for y in range(PATCH_SIZE):
			for x in range(PATCH_SIZE):
				migrated.set_pixel(PATCH_ORIGIN.x + x, PATCH_ORIGIN.y + y, source.get_pixel(origin.x + x, origin.y + y))
		var error := migrated.save_png(path)
		if error != OK:
			push_error("Could not save migrated %s" % path)
			return false
	return true

func _ready() -> void:
	if not _patch_workbench() or not _patch_preview() or not _patch_canvas() or not _migrate_sources():
		get_tree().quit(1)
		return
	print("Hole Corner now edits the bottom-right dirt corner on a full 32x32 tile")
	get_tree().quit()
