extends Node

const WORKBENCH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const RUNTIME := "res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd"

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
	var workbench := FileAccess.get_file_as_string(WORKBENCH)
	workbench = _replace_once(
		workbench,
		"const HOLE_CORNER_ORIGIN := Vector2i(LOGICAL_SIZE - HOLE_CORNER_SIZE, LOGICAL_SIZE - HOLE_CORNER_SIZE)",
		"const HOLE_CORNER_ART_ORIGIN := Vector2i(9, 9)\nconst HOLE_CORNER_LEGACY_SIZE := 14",
		"centered Hole Corner constants"
	)
	var old_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var corner: Image
	if FileAccess.file_exists(editable_path):
		corner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
	else:
		corner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
	corner.convert(Image.FORMAT_RGBA8)
	corner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	# Preserve the complete 32x32 authored stamp. Existing curves stay in the
	# top-left vertex, while the remaining pixels provide editable overscan.
	return corner
'''
	var new_loader := '''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
	var editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
	var corner: Image
	if FileAccess.file_exists(editable_path):
		corner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
	else:
		corner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
	corner.convert(Image.FORMAT_RGBA8)
	corner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	# Migrate the old top-left 14x14 authoring layout once, in memory. The curve
	# now sits around the middle of the 32x32 stamp, leaving real paintable room
	# on every side. Already-centered or custom full-canvas art is left untouched.
	var has_legacy_pixels := false
	var has_outside_pixels := false
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			if corner.get_pixel(x, y).a <= 0.05:
				continue
			if x < HOLE_CORNER_LEGACY_SIZE and y < HOLE_CORNER_LEGACY_SIZE:
				has_legacy_pixels = true
			else:
				has_outside_pixels = true
	if has_legacy_pixels and not has_outside_pixels:
		var centered := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
		centered.fill(Color.TRANSPARENT)
		for y in range(HOLE_CORNER_LEGACY_SIZE):
			for x in range(HOLE_CORNER_LEGACY_SIZE):
				centered.set_pixelv(HOLE_CORNER_ART_ORIGIN + Vector2i(x, y), corner.get_pixel(x, y))
		corner = centered
	return corner
'''
	workbench = _replace_once(workbench, old_loader, new_loader, "centered Hole Corner loader")
	workbench = workbench.replace(
		"Paint the independent TOP-LEFT HOLE CORNER on the full 32x32 overscan stamp. The curve keeps its vertex anchor, but you may draw beyond the old 14x14 box.",
		"Paint the independent HOLE CORNER on the full 32x32 overscan stamp. The old curve is centered automatically, leaving room on the left, top, right and bottom for outer-corner continuation."
	)
	if not _write(WORKBENCH, workbench):
		get_tree().quit(1)
		return

	var preview := FileAccess.get_file_as_string(PREVIEW)
	preview = _replace_once(
		preview,
		"const CORNER_PATCH_SIZE := LOGICAL_SIZE",
		"const CORNER_PATCH_SIZE := LOGICAL_SIZE\nconst HOLE_VERTEX_OFFSET := 12.0",
		"preview Hole Corner offset"
	)
	var old_preview_rect := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# The full-cell stamp keeps the original 3 px vertex overscan anchor.
	var position := rect.position - Vector2(3.0, 3.0)
	match frame:
		1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 3.0, rect.position.y - 3.0)
		2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 3.0, rect.end.y - CORNER_PATCH_SIZE + 3.0)
		3: position = Vector2(rect.position.x - 3.0, rect.end.y - CORNER_PATCH_SIZE + 3.0)
	return Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''
	var new_preview_rect := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# The authored curve is centered in the full stamp. This offset places its
	# original vertex at the same world-grid joint while retaining overscan on
	# both sides of the curve.
	var position := rect.position - Vector2(HOLE_VERTEX_OFFSET, HOLE_VERTEX_OFFSET)
	match frame:
		1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET, rect.position.y - HOLE_VERTEX_OFFSET)
		2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET, rect.end.y - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET)
		3: position = Vector2(rect.position.x - HOLE_VERTEX_OFFSET, rect.end.y - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET)
	return Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''
	preview = _replace_once(preview, old_preview_rect, new_preview_rect, "preview centered placement")
	var old_preview_face := '''			var origin_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				for local_x in range(CELL_SIZE):
					var world_x := origin_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
'''
	var new_preview_face := '''			var origin_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			var left_open := not _is_solid(cell + Vector2i.LEFT)
			var right_open := not _is_solid(cell + Vector2i.RIGHT)
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				# Topology-owned rounded caps: only exposed outer ends are inset. Hole
				# Corner artwork never participates in this mask, so the two systems
				# cannot erase or notch each other.
				var cap_inset := maxi(0, 4 - distance)
				var start_x := cap_inset if left_open else 0
				var end_x := CELL_SIZE - cap_inset if right_open else CELL_SIZE
				for local_x in range(start_x, end_x):
					var world_x := origin_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
'''
	preview = _replace_once(preview, old_preview_face, new_preview_face, "preview curved face caps")
	if not _write(PREVIEW, preview):
		get_tree().quit(1)
		return

	var runtime := FileAccess.get_file_as_string(RUNTIME)
	var old_runtime_face := '''	for y in range(TILE_SIZE + depth):
		for x in range(TILE_SIZE):
			var shifted_y := y - depth
			if shifted_y < 0 or shifted_y >= TILE_SIZE:
				continue
			if tile.get_pixel(x, shifted_y).a <= 0.05:
				continue
			var original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
			if original_alpha > 0.05:
				continue
			var sample_y := posmod(y - TILE_SIZE, TILE_SIZE)
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := float(y - TILE_SIZE + 1) / float(maxi(depth, 1))
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	var new_runtime_face := '''	for y in range(TILE_SIZE + depth):
		for x in range(TILE_SIZE):
			var shifted_y := y - depth
			if shifted_y < 0 or shifted_y >= TILE_SIZE:
				continue
			if tile.get_pixel(x, shifted_y).a <= 0.05:
				continue
			var original_alpha := tile.get_pixel(x, y).a if y < TILE_SIZE else 0.0
			if original_alpha > 0.05:
				continue
			var sample_y := posmod(y - TILE_SIZE, TILE_SIZE)
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := float(y - TILE_SIZE + 1) / float(maxi(depth, 1))
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)

	# Draw the stable full downward face last, but round only actual exposed outer
	# ends. This is based solely on the tile exposure mask and never on Hole Corner
	# alpha, preventing the previous corner/front-mask feedback loop.
	var left_open := (mask & 8) != 0
	var right_open := (mask & 2) != 0
	for distance in range(1, depth + 1):
		var y := TILE_SIZE + distance - 1
		var sample_y := clampi(roundi(float(distance - 1) * float(TILE_SIZE - 1) / float(maxi(depth - 1, 1))), 0, TILE_SIZE - 1)
		var cap_inset := maxi(0, 8 - distance * 2)
		var start_x := cap_inset if left_open else 0
		var end_x := TILE_SIZE - cap_inset if right_open else TILE_SIZE
		for x in range(start_x, end_x):
			var color := front.get_pixel(x, sample_y)
			var depth_ratio := float(distance) / float(maxi(depth, 1))
			color = color.darkened(0.10 + depth_ratio * 0.18)
			color.a = 1.0
			result.set_pixel(x, y, color)
	return result
'''
	runtime = _replace_once(runtime, old_runtime_face, new_runtime_face, "runtime curved face caps")
	if not _write(RUNTIME, runtime):
		get_tree().quit(1)
		return

	print("Centered Hole Corner authoring and topology-only curved front caps applied.")
	get_tree().quit()
