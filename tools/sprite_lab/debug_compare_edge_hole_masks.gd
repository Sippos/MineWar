extends Node

const EDGE_PATH := "res://tools/sprite_lab/source/dome_material/easy_edge_joint_top_left_32.png"
const HOLE_PATH := "res://tools/sprite_lab/source/dome_material/easy_hole_corner_top_left_32.png"
const SIZE := 14

func _ready() -> void:
	var edge := Image.load_from_file(ProjectSettings.globalize_path(EDGE_PATH))
	var hole := Image.load_from_file(ProjectSettings.globalize_path(HOLE_PATH))
	if edge == null or hole == null or edge.is_empty() or hole.is_empty():
		push_error("Could not load source images")
		get_tree().quit(1)
		return
	edge.convert(Image.FORMAT_RGBA8)
	hole.convert(Image.FORMAT_RGBA8)
	var mismatches := 0
	print("EDGE | HOLE | EXPECTED INVERSE")
	for y in range(SIZE):
		var edge_row := ""
		var hole_row := ""
		var expected_row := ""
		for x in range(SIZE):
			var edge_solid := edge.get_pixel(x, y).a > 0.05
			var hole_solid := hole.get_pixel(x, y).a > 0.05
			edge_row += "#" if edge_solid else "."
			hole_row += "#" if hole_solid else "."
			expected_row += "." if edge_solid else "#"
			if hole_solid == edge_solid:
				mismatches += 1
		print("%02d %s | %s | %s" % [y, edge_row, hole_row, expected_row])
	print("alpha inverse mismatches=%d" % mismatches)
	get_tree().quit(0 if mismatches == 0 else 2)
