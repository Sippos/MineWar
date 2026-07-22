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
	var old_preview := '''	# Pass 2: a downward-open block owns a COMPLETE cell-width front face.
	# The side-border curve may remain behind it, but may never shrink or notch
	# the face. Only actual solid topology blocks the overlay; decorative alpha
	# from neighbouring side rims does not.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var face_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				for local_x in range(CELL_SIZE):
					var world_x := face_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					var topology_cell := Vector2i(world_x / CELL_SIZE, world_y / CELL_SIZE)
					if _is_solid(topology_cell):
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
'''
	var new_preview := '''	# Pass 2: downward-open blocks own complete-width faces at the top, while
	# only the OUTER lower corners of each contiguous run are rounded. Internal
	# joins remain square so neighbouring blocks merge into one continuous wall.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var left_has_face := _is_solid(cell + Vector2i.LEFT) and not _is_solid(cell + Vector2i.LEFT + Vector2i.DOWN)
			var right_has_face := _is_solid(cell + Vector2i.RIGHT) and not _is_solid(cell + Vector2i.RIGHT + Vector2i.DOWN)
			var radius := clampi(mini(front_depth, CELL_SIZE) / 4, 2, 8)
			var face_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				for local_x in range(CELL_SIZE):
					var world_x := face_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					var topology_cell := Vector2i(world_x / CELL_SIZE, world_y / CELL_SIZE)
					if _is_solid(topology_cell):
						continue
					var keep_pixel := true
					if distance > front_depth - radius:
						var dy := distance - (front_depth - radius) - 1
						if not left_has_face and local_x < radius:
							var dx_left := radius - 1 - local_x
							keep_pixel = dx_left * dx_left + dy * dy <= radius * radius
						if keep_pixel and not right_has_face and local_x >= CELL_SIZE - radius:
							var dx_right := local_x - (CELL_SIZE - radius)
							keep_pixel = dx_right * dx_right + dy * dy <= radius * radius
					if keep_pixel:
						result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
'''
	preview = _replace_once(preview, old_preview, new_preview, "preview full face block")
	if not _write(PREVIEW_PATH, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME_PATH)
	var old_runtime := '''	# The downward face is always the complete tile width. It is drawn last so
	# a rounded left/right border cannot bite into or shrink the front surface.
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
		var depth_ratio := 0.0 if depth <= 1 else float(distance - 1) / float(depth - 1)
		for x in range(TILE_SIZE):
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
'''
	var new_runtime := '''	# Complete width at the top, rounded only at lower OUTER corners. Bit 8/2
	# indicate exposed left/right sides; those are the run ends that receive caps.
	var round_left := (mask & 8) != 0
	var round_right := (mask & 2) != 0
	var radius := clampi(mini(depth, TILE_SIZE) / 4, 4, 16)
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
		var depth_ratio := 0.0 if depth <= 1 else float(distance - 1) / float(depth - 1)
		for x in range(TILE_SIZE):
			var keep_pixel := true
			if distance > depth - radius:
				var dy := distance - (depth - radius) - 1
				if round_left and x < radius:
					var dx_left := radius - 1 - x
					keep_pixel = dx_left * dx_left + dy * dy <= radius * radius
				if keep_pixel and round_right and x >= TILE_SIZE - radius:
					var dx_right := x - (TILE_SIZE - radius)
					keep_pixel = dx_right * dx_right + dy * dy <= radius * radius
			if not keep_pixel:
				continue
			var color := front.get_pixel(x, sample_y)
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
'''
	runtime = _replace_once(runtime, old_runtime, new_runtime, "runtime full face block")
	if not _write(RUNTIME_PATH, runtime):
		get_tree().quit(1)
		return
	print("Rounded lower outer corners added while preserving full-width top faces")
	get_tree().quit(0)
