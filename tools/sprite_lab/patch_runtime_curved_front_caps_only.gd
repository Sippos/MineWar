extends Node

const PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var old := '''	# The downward-facing wall is always the complete tile width. Drawing it last
	# prevents rounded corner masks from cutting visible notches into the face.
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
		var depth_ratio := float(distance - 1) / float(maxi(depth - 1, 1))
		for x in range(TILE_SIZE):
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
'''
	var replacement := '''	# The downward wall remains stable and full-width through connected runs, but
	# actual exposed outer ends receive a tiny rounded cap. This uses only the
	# topology mask; Hole Corner artwork cannot cut or reshape the front surface.
	var left_open := (mask & 8) != 0
	var right_open := (mask & 2) != 0
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
		var depth_ratio := float(distance - 1) / float(maxi(depth - 1, 1))
		var cap_inset := maxi(0, 8 - distance * 2)
		var start_x := cap_inset if left_open else 0
		var end_x := TILE_SIZE - cap_inset if right_open else TILE_SIZE
		for x in range(start_x, end_x):
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
'''
	if not text.contains(old):
		push_error("Runtime full-width face anchor missing")
		get_tree().quit(1)
		return
	text = text.replace(old, replacement)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write runtime renderer")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Runtime topology-only curved front caps applied.")
	get_tree().quit()
