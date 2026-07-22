extends Node

const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME_PATH := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

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
	var preview := FileAccess.get_file_as_string(PREVIEW_PATH)
	var preview_helper_anchor := '''\treturn color

func _rebuild_extrusion_texture() -> void:'''
	var preview_helper_replacement := '''\treturn color

func _front_face_mask_allows(local_x: int, local_y: int, face_width: int, face_height: int, round_left: bool, round_right: bool) -> bool:
	# Independent front-surface mask. It rounds only the BOTTOM corners of an
	# exposed face end. Tunnel junctions stay square because their side neighbour
	# is solid, and Hole Corner artwork is never sampled here.
	var radius := mini(5, face_height)
	if radius <= 1:
		return true
	var center_y := float(face_height - radius)
	var sample_y := float(local_y) + 0.5
	if sample_y < center_y:
		return true
	var radius_squared := float(radius * radius)
	if round_left and local_x < radius:
		var left_dx := float(local_x) + 0.5 - float(radius)
		var left_dy := sample_y - center_y
		if left_dx * left_dx + left_dy * left_dy > radius_squared:
			return false
	if round_right and local_x >= face_width - radius:
		var right_dx := float(local_x) + 0.5 - float(face_width - radius)
		var right_dy := sample_y - center_y
		if right_dx * right_dx + right_dy * right_dy > radius_squared:
			return false
	return true

func _rebuild_extrusion_texture() -> void:'''
	preview = _replace_once(preview, preview_helper_anchor, preview_helper_replacement, "preview front mask helper")

	var old_preview_face := '''\t\t\tvar left_open := not _is_solid(cell + Vector2i.LEFT)
\t\t\tvar right_open := not _is_solid(cell + Vector2i.RIGHT)
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar world_y := face_y + distance - 1
\t\t\t\tif world_y < 0 or world_y >= height:
\t\t\t\t\tbreak
\t\t\t\t# Topology-owned rounded caps: only exposed outer ends are inset. Hole
\t\t\t\t# Corner artwork never participates in this mask, so the two systems
\t\t\t\t# cannot erase or notch each other.
\t\t\t\tvar cap_inset := maxi(0, 4 - distance)
\t\t\t\tvar start_x := cap_inset if left_open else 0
\t\t\t\tvar end_x := CELL_SIZE - cap_inset if right_open else CELL_SIZE
\t\t\t\tfor local_x in range(start_x, end_x):
\t\t\t\t\tvar world_x := origin_x + local_x
\t\t\t\t\tif world_x < 0 or world_x >= width:
\t\t\t\t\t\tcontinue
\t\t\t\t\tresult.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))'''
	var new_preview_face := '''\t\t\tvar left_open := not _is_solid(cell + Vector2i.LEFT)
\t\t\tvar right_open := not _is_solid(cell + Vector2i.RIGHT)
\t\t\tfor distance in range(1, front_depth + 1):
\t\t\t\tvar world_y := face_y + distance - 1
\t\t\t\tif world_y < 0 or world_y >= height:
\t\t\t\t\tbreak
\t\t\t\tvar local_y := distance - 1
\t\t\t\tfor local_x in range(CELL_SIZE):
\t\t\t\t\tvar world_x := origin_x + local_x
\t\t\t\t\tif world_x < 0 or world_x >= width:
\t\t\t\t\t\tcontinue
\t\t\t\t\tif not _front_face_mask_allows(local_x, local_y, CELL_SIZE, front_depth, left_open, right_open):
\t\t\t\t\t\t# Clear the silhouette pass too, so the missing corner genuinely reveals
\t\t\t\t\t\t# cave space instead of exposing an older side-extrusion pixel.
\t\t\t\t\t\tresult.set_pixel(world_x, world_y, Color.TRANSPARENT)
\t\t\t\t\t\tcontinue
\t\t\t\t\tresult.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))'''
	preview = _replace_once(preview, old_preview_face, new_preview_face, "preview bottom-rounded front face")
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	var runtime_helper_anchor := '''func _build_extrusion_image(source_id: int, mask: int) -> Image:'''
	var runtime_helper_replacement := '''func _front_face_mask_allows(local_x: int, local_y: int, face_width: int, face_height: int, round_left: bool, round_right: bool) -> bool:
	# Runtime equivalent of the workbench mask: only exposed outer ends receive
	# bottom rounding. A tunnel wall has a solid side neighbour and remains square.
	var radius := mini(8, face_height)
	if radius <= 1:
		return true
	var center_y := float(face_height - radius)
	var sample_y := float(local_y) + 0.5
	if sample_y < center_y:
		return true
	var radius_squared := float(radius * radius)
	if round_left and local_x < radius:
		var left_dx := float(local_x) + 0.5 - float(radius)
		var left_dy := sample_y - center_y
		if left_dx * left_dx + left_dy * left_dy > radius_squared:
			return false
	if round_right and local_x >= face_width - radius:
		var right_dx := float(local_x) + 0.5 - float(face_width - radius)
		var right_dy := sample_y - center_y
		if right_dx * right_dx + right_dy * right_dy > radius_squared:
			return false
	return true

func _build_extrusion_image(source_id: int, mask: int) -> Image:'''
	runtime = _replace_once(runtime, runtime_helper_anchor, runtime_helper_replacement, "runtime front mask helper")

	var old_runtime_face := '''\t# The downward wall remains stable and full-width through connected runs, but
\t# actual exposed outer ends receive a tiny rounded cap. This uses only the
\t# topology mask; Hole Corner artwork cannot cut or reshape the front surface.
\tvar left_open := (mask & 8) != 0
\tvar right_open := (mask & 2) != 0
\tfor distance in range(1, depth + 1):
\t\tvar y := TILE_SIZE + distance - 1
\t\tvar sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
\t\tvar depth_ratio := float(distance - 1) / float(maxi(depth - 1, 1))
\t\tvar cap_inset := maxi(0, 8 - distance * 2)
\t\tvar start_x := cap_inset if left_open else 0
\t\tvar end_x := TILE_SIZE - cap_inset if right_open else TILE_SIZE
\t\tfor x in range(start_x, end_x):
\t\t\tvar color := front.get_pixel(x, sample_y)
\t\t\tcolor = color.darkened(0.10 + depth_ratio * 0.18)
\t\t\tcolor.a = 1.0
\t\t\tresult.set_pixel(x, y, color)
\treturn result'''
	var new_runtime_face := '''\t# The front face owns a separate bottom-corner mask. Horizontal runs remain
\t# seamless, tunnel junctions stay square, and only sides open to cave space
\t# receive the rounded lower cap.
\tvar left_open := (mask & 8) != 0
\tvar right_open := (mask & 2) != 0
\tfor distance in range(1, depth + 1):
\t\tvar y := TILE_SIZE + distance - 1
\t\tvar local_y := distance - 1
\t\tvar sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
\t\tvar depth_ratio := float(distance - 1) / float(maxi(depth - 1, 1))
\t\tfor x in range(TILE_SIZE):
\t\t\tif not _front_face_mask_allows(x, local_y, TILE_SIZE, depth, left_open, right_open):
\t\t\t\tresult.set_pixel(x, y, Color.TRANSPARENT)
\t\t\t\tcontinue
\t\t\tvar color := front.get_pixel(x, sample_y)
\t\t\tcolor = color.darkened(0.10 + depth_ratio * 0.18)
\t\t\tcolor.a = 1.0
\t\t\tresult.set_pixel(x, y, color)
\treturn result'''
	runtime = _replace_once(runtime, old_runtime_face, new_runtime_face, "runtime bottom-rounded front face")
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return

	print("Independent bottom-rounded front masks applied to preview and runtime.")
	get_tree().quit()
