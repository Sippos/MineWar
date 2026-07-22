extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const LOGICAL_SIZE := 32
const HALF_SIZE := 16
const TIERS: Array[String] = ["easy", "medium", "hard"]

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

func _make_exact_starter(edge_joint: Image) -> Image:
	var edge: Image = edge_joint.duplicate()
	edge.convert(Image.FORMAT_RGBA8)
	edge.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(HALF_SIZE):
		for x in range(HALF_SIZE):
			result.set_pixel(HALF_SIZE + x, HALF_SIZE + y, edge.get_pixel(x, y))
	return result

func _patch_loader() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	var old := '''\telse:
\t\tsource = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
\t\tsource.fill(Color.TRANSPARENT)
\tsource.convert(Image.FORMAT_RGBA8)
'''
	var replacement := '''\telse:
\t\t# First-time Hole Corner starter: reuse the Edge Joint curve literally.
\t\t# Its top-left 16x16 pixels are copied to the centered stamp's bottom-right
\t\t# quadrant, so shape, thickness, palette and endpoint positions are identical.
\t\tsource = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
\t\tsource.fill(Color.TRANSPARENT)
\t\tfor y in range(16):
\t\t\tfor x in range(16):
\t\t\t\tsource.set_pixel(16 + x, 16 + y, edge_joint.get_pixel(x, y))
\tsource.convert(Image.FORMAT_RGBA8)
'''
	text = _replace_once(text, old, replacement, "Hole Corner exact Edge Joint starter")
	if text.is_empty():
		return false
	text = text.replace(
		"Paint one centered grid vertex. The cross at pixel 16/16 is the corner: draw the canonical curve in the bottom-right quadrant and extend either border endpoint across the center when needed. Preview and export rotate it four ways.",
		"Paint one centered grid vertex. The starter in the bottom-right quadrant is an exact pixel-for-pixel copy of the Edge Joint curve at origin 16/16. Extend either border endpoint across the center when needed; preview and export rotate it four ways."
	)
	return _write(WORKBENCH_PATH, text)

func _regenerate_sources() -> bool:
	for tier in TIERS:
		var edge_path := SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier
		var hole_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
		var edge := Image.load_from_file(ProjectSettings.globalize_path(edge_path))
		if edge == null or edge.is_empty():
			push_error("Could not load %s" % edge_path)
			return false
		var starter := _make_exact_starter(edge)
		var result: Error = starter.save_png(hole_path)
		if result != OK:
			push_error("Could not save %s" % hole_path)
			return false
	var easy_path := SOURCE_DIR + "/easy_hole_corner_top_left_32.png"
	var unmineable_path := SOURCE_DIR + "/unmineable_hole_corner_top_left_32.png"
	var easy := Image.load_from_file(ProjectSettings.globalize_path(easy_path))
	if easy == null or easy.is_empty():
		push_error("Could not reload Easy Hole Corner")
		return false
	if easy.save_png(unmineable_path) != OK:
		push_error("Could not save Unmineable Hole Corner")
		return false
	return true

func _verify() -> bool:
	for tier in TIERS:
		var edge := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_edge_joint_top_left_32.png" % tier))
		var hole := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier))
		if edge == null or hole == null or edge.is_empty() or hole.is_empty():
			return false
		edge.convert(Image.FORMAT_RGBA8)
		hole.convert(Image.FORMAT_RGBA8)
		for y in range(HALF_SIZE):
			for x in range(HALF_SIZE):
				if edge.get_pixel(x, y) != hole.get_pixel(HALF_SIZE + x, HALF_SIZE + y):
					push_error("Curve mismatch for %s at %s" % [tier, Vector2i(x, y)])
					return false
	print("Verified: every Hole Corner starter exactly matches its Edge Joint curve at offset (16,16)")
	return true

func _ready() -> void:
	if not _patch_loader() or not _regenerate_sources() or not _verify():
		get_tree().quit(1)
		return
	get_tree().quit()
