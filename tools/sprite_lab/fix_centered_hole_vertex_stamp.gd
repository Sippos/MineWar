extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const WORLD_PATH := "res://scripts/systems/world_generation/world.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const LOGICAL_SIZE := 32
const HALF_SIZE := 16
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

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	var old_rect := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# Full-cell replacement stamp: the frame exactly covers the empty cell.
	return rect
'''
	var new_rect := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# A Hole Corner is a 32x32 VERTEX stamp centered on the grid intersection,
	# not a texture centered inside the empty cell. Frame 0 is authored with its
	# curved rim in the bottom-right quadrant around the central vertex.
	var vertex := rect.position
	match frame:
		1:
			vertex = Vector2(rect.end.x, rect.position.y)
		2:
			vertex = rect.end
		3:
			vertex = Vector2(rect.position.x, rect.end.y)
	return Rect2(vertex - Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5), Vector2(CELL_SIZE, CELL_SIZE))
'''
	text = _replace_once(text, old_rect, new_rect, "preview vertex placement")
	if text.is_empty():
		return false
	return _write(PREVIEW_PATH, text)

func _patch_world() -> bool:
	var text := FileAccess.get_file_as_string(WORLD_PATH)
	var old_position := '''		# Atlas frame origin matches the empty cell exactly; no hidden corner offset.
		sprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell)))
'''
	var new_position := '''		# The 64x64 atlas frame is a vertex stamp. Position its center on the actual
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
	text = _replace_once(text, old_position, new_position, "runtime vertex placement")
	if text.is_empty():
		return false
	return _write(WORLD_PATH, text)

func _patch_workbench_text() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = text.replace(
		"%s HOLE CORNER • EDIT FULL 32x32 VERTEX STAMP",
		"%s HOLE CORNER • CENTERED VERTEX STAMP"
	)
	text = text.replace(
		"Paint the complete 32x32 HOLE CORNER replacement stamp. Draw both straight-border endpoints and their rounded connection directly on the cave background. Export rotates the complete stamp into all four directions.",
		"Paint one centered grid vertex. The cross at pixel 16/16 is the corner: draw the canonical curve in the bottom-right quadrant and extend either border endpoint across the center when needed. Preview and export rotate it four ways."
	)
	return _write(WORKBENCH_PATH, text)

func _clean_sources() -> bool:
	# Keep only the canonical bottom-right quadrant from the broken migration.
	# The full canvas remains editable after loading, but all floating legacy arcs
	# in the other three quadrants are removed.
	for tier in TIERS:
		var path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		if not FileAccess.file_exists(path):
			continue
		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		if source == null or source.is_empty():
			continue
		source.convert(Image.FORMAT_RGBA8)
		source.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
		var clean := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		clean.fill(Color.TRANSPARENT)
		for y in range(HALF_SIZE, LOGICAL_SIZE):
			for x in range(HALF_SIZE, LOGICAL_SIZE):
				clean.set_pixel(x, y, source.get_pixel(x, y))
		var result := clean.save_png(path)
		if result != OK:
			push_error("Could not clean %s" % path)
			return false
	return true

func _ready() -> void:
	if not _patch_preview() or not _patch_world() or not _patch_workbench_text() or not _clean_sources():
		get_tree().quit(1)
		return
	print("Hole Corner is now a centered vertex stamp with one canonical quadrant")
	get_tree().quit()
