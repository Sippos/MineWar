extends Control

const CORNER_BUILDER = preload("res://tools/sprite_lab/dome_corner_builder.gd")

const MAP_SIZE := Vector2i(12, 8)
const CELL_SIZE := 32
const LOGICAL_SIZE := 32
# Hole Corner artwork uses the complete logical cell as an overscan stamp.
# The actual curve may stay small, but artists can paint beyond the old 14x14 box.
const CORNER_PATCH_SIZE := 32
const HOLE_VERTEX_OFFSET := 16.0
const DEFAULT_FRONT_DEPTH := 10
const CAVE_COLOR := Color("111725")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MATERIAL_TIERS: Array[String] = ["unmineable", "easy", "medium", "hard", "gems", "cracks"]

enum CellType {
	EMPTY,
	UNMINEABLE,
	EASY,
	MEDIUM,
	HARD,
	GEMS,
	CRACKS,
}

enum PreviewBrush {
	DIG,
	EASY,
	MEDIUM,
	HARD,
	UNMINEABLE,
	GEMS,
	CRACKS,
}

var mass_image: Image
var mass_texture: ImageTexture
var border_images: Dictionary = {}
var corner_images: Dictionary = {}
var convex_images: Dictionary = {}
var front_images: Dictionary = {}
var composite_images: Dictionary = {}
var composite_textures: Dictionary = {}
var inside_corner_images: Dictionary = {}
var inside_corner_textures: Dictionary = {}
var cells: Dictionary = {}
var dragging := false
var drag_button := MOUSE_BUTTON_LEFT
var last_drag_cell := Vector2i(-1, -1)
var hovered_cell := Vector2i(-1, -1)
var rounded_light_corners := true
# The normal EASY cells in the demo cave act as the currently selected material.
# This makes UNMINEABLE edge joints and Hole Corners immediately visible while
# preserving the explicit medium/hard comparison blocks.
var primary_preview_tier := "easy"
var preview_brush: int = PreviewBrush.DIG
var show_front_faces := true
var front_depth := DEFAULT_FRONT_DEPTH
var extrusion_texture: ImageTexture
var extrusion_dirty := true

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reset_layout()

func _normalized_image(source: Image) -> Image:
	var image := source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != LOGICAL_SIZE or image.get_height() != LOGICAL_SIZE:
		image.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	return image

func set_material_library(new_mass_image: Image, new_border_images: Dictionary, new_corner_images: Dictionary, new_convex_images: Dictionary, new_front_images: Dictionary) -> void:
	set_all_material_images(new_mass_image, new_border_images, new_corner_images, new_convex_images, new_front_images)

func set_all_material_images(new_mass_image: Image, new_border_images: Dictionary, new_corner_images: Dictionary, new_convex_images: Dictionary, new_front_images: Dictionary) -> void:
	mass_image = _normalized_image(new_mass_image)
	mass_texture = ImageTexture.create_from_image(mass_image)
	border_images.clear()
	corner_images.clear()
	convex_images.clear()
	front_images.clear()
	for tier in MATERIAL_TIERS:
		if new_border_images.has(tier):
			border_images[tier] = _normalized_image(new_border_images[tier] as Image)
		if new_corner_images.has(tier):
			corner_images[tier] = _normalized_image(new_corner_images[tier] as Image)
		if new_convex_images.has(tier):
			convex_images[tier] = _normalized_image(new_convex_images[tier] as Image)
		if new_front_images.has(tier):
			front_images[tier] = _normalized_image(new_front_images[tier] as Image)

	_rebuild_material_textures()

# Compatibility for older workbench callers.
func set_material_images(new_mass_image: Image, selected_top_border: Image, unmineable_top_border: Image, selected_top_left_corner: Image, unmineable_top_left_corner: Image, selected_top_left_convex: Image, unmineable_top_left_convex: Image) -> void:
	var borders := {
		"unmineable": unmineable_top_border,
		"easy": selected_top_border,
		"medium": selected_top_border,
		"hard": selected_top_border,
	}
	var corners := {
		"unmineable": unmineable_top_left_corner,
		"easy": selected_top_left_corner,
		"medium": selected_top_left_corner,
		"hard": selected_top_left_corner,
	}
	var joints := {
		"unmineable": unmineable_top_left_convex,
		"easy": selected_top_left_convex,
		"medium": selected_top_left_convex,
		"hard": selected_top_left_convex,
	}
	set_all_material_images(new_mass_image, borders, corners, joints, {})

func set_rounded_light_corners(value: bool) -> void:
	rounded_light_corners = value
	_rebuild_material_textures()

func set_primary_preview_tier(tier: String) -> void:
	if not MATERIAL_TIERS.has(tier):
		return
	primary_preview_tier = tier
	_mark_extrusion_dirty()

func set_preview_brush(value: int) -> void:
	preview_brush = clampi(value, PreviewBrush.DIG, PreviewBrush.CRACKS)

func set_front_faces_visible(value: bool) -> void:
	show_front_faces = value
	queue_redraw()

func set_front_depth(value: int) -> void:
	front_depth = clampi(value, 2, 32)
	_mark_extrusion_dirty()

func _mark_extrusion_dirty() -> void:
	extrusion_dirty = true
	queue_redraw()

func _tier_for_cell_type(cell_type: int) -> String:
	match cell_type:
		CellType.UNMINEABLE:
			return "unmineable"
		CellType.MEDIUM:
			return "medium"
		CellType.HARD:
			return "hard"
		CellType.GEMS:
			return "gems"
		CellType.CRACKS:
			return "cracks"
		_:
			return "easy"

func _cell_type_for_tier(tier: String) -> int:
	match tier:
		"unmineable":
			return CellType.UNMINEABLE
		"medium":
			return CellType.MEDIUM
		"hard":
			return CellType.HARD
		"gems":
			return CellType.GEMS
		"cracks":
			return CellType.CRACKS
		_:
			return CellType.EASY

func _rotate_corner_patch(source: Image, turns: int) -> Image:
	var normalized := posmod(turns, 4)
	var result := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var destination := Vector2i(x, y)
			match normalized:
				1: destination = Vector2i(CORNER_PATCH_SIZE - 1 - y, x)
				2: destination = Vector2i(CORNER_PATCH_SIZE - 1 - x, CORNER_PATCH_SIZE - 1 - y)
				3: destination = Vector2i(y, CORNER_PATCH_SIZE - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result

func _build_vertex_hole_images(hole_source: Image) -> Array[Image]:
	var source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	source_patch.fill(Color.TRANSPARENT)
	if hole_source != null and not hole_source.is_empty():
		for y in range(CORNER_PATCH_SIZE):
			for x in range(CORNER_PATCH_SIZE):
				source_patch.set_pixel(x, y, hole_source.get_pixel(x, y))
	var result: Array[Image] = []
	for frame in range(4):
		result.append(_rotate_corner_patch(source_patch, frame))
	return result

func _build_logical_composite_images(base: Image, top_border: Image, edge_joint: Image) -> Array[Image]:
	var result: Array[Image] = []
	for mask in range(16):
		result.append(CORNER_BUILDER.build_composite_tile(base, top_border, mask, edge_joint))
	return result

func _build_square_composite_images(base: Image, top_border: Image) -> Array[Image]:
	var directions: Array[Image] = []
	for turn in range(4):
		directions.append(CORNER_BUILDER.rotate_quarters(top_border, turn))
	var result: Array[Image] = []
	for mask in range(16):
		var tile := base.duplicate()
		for direction_index in range(4):
			if (mask & (1 << direction_index)) != 0:
				tile.blend_rect(directions[direction_index], Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i.ZERO)
		result.append(tile)
	return result

func _images_to_textures(images: Array) -> Array[ImageTexture]:
	var result: Array[ImageTexture] = []
	for value: Variant in images:
		result.append(ImageTexture.create_from_image(value as Image))
	return result

func _rebuild_material_textures() -> void:
	if mass_image == null:
		return
	composite_images.clear()
	composite_textures.clear()
	inside_corner_images.clear()
	inside_corner_textures.clear()
	for tier in MATERIAL_TIERS:
		# Create placeholder empty images for any tier missing stamps.
		# This ensures overlay tiers (gems, cracks) with empty/transparent
		# stamps still get valid texture entries, preventing dark placeholder
		# boxes when the tier is selected in the preview.
		var border: Image = border_images.get(tier, null) as Image
		var joint: Image = convex_images.get(tier, null) as Image
		var corner: Image = corner_images.get(tier, null) as Image
		if border == null:
			border = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
			border.fill(Color.TRANSPARENT)
		var tile_images: Array[Image]
		if rounded_light_corners:
			tile_images = _build_logical_composite_images(mass_image, border, joint)
		else:
			tile_images = _build_square_composite_images(mass_image, border)
		var hole_images := _build_vertex_hole_images(corner)
		composite_images[tier] = tile_images
		composite_textures[tier] = _images_to_textures(tile_images)
		inside_corner_images[tier] = hole_images
		inside_corner_textures[tier] = _images_to_textures(hole_images)
	_mark_extrusion_dirty()


func reset_layout() -> void:
	cells.clear()
	# Every default solid uses the PRIMARY preview slot. The selected material
	# therefore owns the complete test cave, including its outer ring. Previously
	# the fixed Unmineable ring overlaid its corners while Easy/Medium/Hard were
	# being authored, which looked like cross-material editing interference.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			cells[Vector2i(x, y)] = CellType.EASY
	for y in range(2, 6):
		for x in range(2, 10):
			cells[Vector2i(x, y)] = CellType.EMPTY
	# One isolated shelf keeps the front-face and bottom-mask cases visible, but
	# it also uses the primary slot. Different materials only appear when the
	# artist explicitly paints them with a preview brush.
	cells[Vector2i(4, 4)] = CellType.EASY
	cells[Vector2i(5, 4)] = CellType.EASY
	cells[Vector2i(6, 4)] = CellType.EASY
	cells[Vector2i(3, 2)] = CellType.EASY
	cells[Vector2i(8, 2)] = CellType.EASY
	_mark_extrusion_dirty()

func _is_outer_ring(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1

func _cell_type(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return CellType.UNMINEABLE
	var stored_type := int(cells.get(cell, CellType.EASY))
	# EASY is the preview's primary material slot. Selecting UNMINEABLE now
	# changes the large cave body as well, so its authored corners actually show.
	if stored_type == CellType.EASY:
		return _cell_type_for_tier(primary_preview_tier)
	return stored_type

func _is_solid(cell: Vector2i) -> bool:
	return _cell_type(cell) != CellType.EMPTY

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))

func _exposure_mask(cell: Vector2i) -> int:
	var mask := 0
	for direction_index in range(4):
		if not _is_solid(cell + DIRECTIONS[direction_index]):
			mask |= 1 << direction_index
	return mask

func _textures_for_cell(cell_type: int) -> Array:
	return composite_textures.get(_tier_for_cell_type(cell_type), []) as Array

func _images_for_cell(cell_type: int) -> Array:
	return composite_images.get(_tier_for_cell_type(cell_type), []) as Array

func _corner_textures_for_cell(cell_type: int) -> Array:
	return inside_corner_textures.get(_tier_for_cell_type(cell_type), []) as Array

func _corner_images_for_cell(cell_type: int) -> Array:
	return inside_corner_images.get(_tier_for_cell_type(cell_type), []) as Array

func _write_mask_image(image: Image, origin: Vector2i, owner_type: int, width: int, height: int, solid: PackedByteArray, owners: PackedInt32Array) -> void:
	for image_y in range(image.get_height()):
		var world_y := origin.y + image_y
		if world_y < 0 or world_y >= height:
			continue
		for image_x in range(image.get_width()):
			var world_x := origin.x + image_x
			if world_x < 0 or world_x >= width:
				continue
			if image.get_pixel(image_x, image_y).a <= 0.05:
				continue
			var index := world_y * width + world_x
			solid[index] = 255
			owners[index] = owner_type

func _cell_source_id(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE.x + cell.x

func _write_owned_mask_image(image: Image, origin: Vector2i, owner_type: int, source_cell: Vector2i, width: int, height: int, solid: PackedByteArray, owners: PackedInt32Array, source_cells: PackedInt32Array, hole_mask: PackedByteArray = PackedByteArray()) -> void:
	var source_id := _cell_source_id(source_cell)
	var mark_hole := hole_mask.size() == solid.size()
	for image_y in range(image.get_height()):
		var world_y := origin.y + image_y
		if world_y < 0 or world_y >= height:
			continue
		for image_x in range(image.get_width()):
			var world_x := origin.x + image_x
			if world_x < 0 or world_x >= width:
				continue
			if image.get_pixel(image_x, image_y).a <= 0.05:
				continue
			var index := world_y * width + world_x
			solid[index] = 255
			owners[index] = owner_type
			source_cells[index] = source_id
			if mark_hole:
				hole_mask[index] = 255

func _build_silhouette_data() -> Dictionary:
	var width := MAP_SIZE.x * CELL_SIZE
	var height := MAP_SIZE.y * CELL_SIZE
	var pixel_count := width * height
	var solid := PackedByteArray()
	solid.resize(pixel_count)
	solid.fill(0)
	var owners := PackedInt32Array()
	owners.resize(pixel_count)
	owners.fill(CellType.EMPTY)
	var source_cells := PackedInt32Array()
	source_cells.resize(pixel_count)
	source_cells.fill(-1)
	# Marks pixels that come from an inner concave Hole Corner patch (not a real
	# block face). The front-wall extrusion must never grow beneath these, or it
	# paints stray front tiles into tunnel corners.
	var hole := PackedByteArray()
	hole.resize(pixel_count)
	hole.fill(0)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var cell_type := _cell_type(cell)
			if cell_type == CellType.EMPTY:
				continue
			var images := _images_for_cell(cell_type)
			var mask := _exposure_mask(cell)
			if mask < images.size():
				_write_owned_mask_image(images[mask] as Image, cell * CELL_SIZE, cell_type, cell, width, height, solid, owners, source_cells)

	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if _is_solid(empty_cell):
				continue
			var rect := _cell_rect(empty_cell)
			for rule_value: Variant in rules:
				var rule: Array = rule_value
				var first: Vector2i = rule[0]
				var second: Vector2i = rule[1]
				var diagonal: Vector2i = rule[2]
				var frame: int = rule[3]
				if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
					continue
				var source_cell := empty_cell + diagonal
				var owner_type := _cell_type(source_cell)
				var hole_images := _corner_images_for_cell(owner_type)
				if frame >= hole_images.size():
					continue
				var patch_rect := _hole_corner_patch_rect(rect, frame)
				_write_owned_mask_image(hole_images[frame] as Image, Vector2i(roundi(patch_rect.position.x), roundi(patch_rect.position.y)), owner_type, source_cell, width, height, solid, owners, source_cells, hole)

	return {"width": width, "height": height, "solid": solid, "owners": owners, "source_cells": source_cells, "hole": hole}

func _sample_front_color(owner_type: int, world_x: int, distance: int) -> Color:
	var tier := _tier_for_cell_type(owner_type)
	var source := front_images.get(tier) as Image
	var sample_y := 0
	if front_depth > 1:
		sample_y = clampi(roundi(float(distance - 1) * float(LOGICAL_SIZE - 1) / float(front_depth - 1)), 0, LOGICAL_SIZE - 1)
	var sample_x := posmod(world_x, LOGICAL_SIZE)
	var color := source.get_pixel(sample_x, sample_y) if source != null else Color.TRANSPARENT
	if color.a <= 0.05:
		color = mass_image.get_pixel(sample_x, sample_y)
	var depth_amount := 0.0 if front_depth <= 1 else float(distance - 1) / float(front_depth - 1)
	var shade := lerpf(1.0, 0.58, depth_amount)
	color.r *= shade
	color.g *= shade
	color.b *= shade
	color.a = 1.0
	return color

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

func _rebuild_extrusion_texture() -> void:
	extrusion_dirty = false
	if not show_front_faces or mass_image == null:
		extrusion_texture = null
		return
	var data := _build_silhouette_data()
	var width: int = data["width"]
	var height: int = data["height"]
	var solid: PackedByteArray = data["solid"]
	var owners: PackedInt32Array = data["owners"]
	var source_cells: PackedInt32Array = data["source_cells"]
	var hole: PackedByteArray = data["hole"]
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)

	# Exact locked 16:24 extrusion everywhere by default.
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			if solid[index] != 0:
				continue
			var owner_type := CellType.EMPTY
			var distance := 0
			for step in range(1, front_depth + 1):
				var source_y := y - step
				if source_y < 0:
					break
				var source_index := source_y * width + x
				if solid[source_index] != 0:
					# Inner concave Hole Corner pixels are not a downward block
					# face, so they must not sprout a front wall into the tunnel.
					if hole[source_index] != 0:
						break
					owner_type = owners[source_index]
					distance = step
					break
			if owner_type != CellType.EMPTY:
				result.set_pixel(x, y, _sample_front_color(owner_type, x, distance))

	# A downward-open block owns a COMPLETE cell-width front face. Rounded side
	# silhouettes still generate depth in the first pass, but they may no longer
	# bite notches out of the front wall at Hole Corners.
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var owner_type := _cell_type(cell)
			if owner_type == CellType.EMPTY or _is_solid(cell + Vector2i.DOWN):
				continue
			var origin_x := cell_x * CELL_SIZE
			var face_y := (cell_y + 1) * CELL_SIZE
			# Round only a genuinely free outer tip. A diagonal solid block means this
			# face is meeting a tunnel/Hole Corner transition and must stay square.
			var left_open := not _is_solid(cell + Vector2i.LEFT) and not _is_solid(cell + Vector2i.DOWN + Vector2i.LEFT)
			var right_open := not _is_solid(cell + Vector2i.RIGHT) and not _is_solid(cell + Vector2i.DOWN + Vector2i.RIGHT)
			for distance in range(1, front_depth + 1):
				var world_y := face_y + distance - 1
				if world_y < 0 or world_y >= height:
					break
				var local_y := distance - 1
				for local_x in range(CELL_SIZE):
					var world_x := origin_x + local_x
					if world_x < 0 or world_x >= width:
						continue
					if not _front_face_mask_allows(local_x, local_y, CELL_SIZE, front_depth, left_open, right_open):
						# Clear the silhouette pass too, so the missing corner genuinely reveals
						# cave space instead of exposing an older side-extrusion pixel.
						result.set_pixel(world_x, world_y, Color.TRANSPARENT)
						continue
					result.set_pixel(world_x, world_y, _sample_front_color(owner_type, world_x, distance))
	extrusion_texture = ImageTexture.create_from_image(result)

func _ensure_extrusion_texture() -> void:
	if extrusion_dirty:
		_rebuild_extrusion_texture()

func _draw() -> void:
	var full_rect := Rect2(Vector2.ZERO, Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE))
	draw_rect(full_rect, CAVE_COLOR)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var cell_type := _cell_type(cell)
			if cell_type == CellType.EMPTY:
				continue
			var mask := _exposure_mask(cell)
			var textures := _textures_for_cell(cell_type)
			if mask < textures.size() and textures[mask] != null:
				draw_texture_rect(textures[mask], _cell_rect(cell), false)
			else:
				draw_rect(_cell_rect(cell), Color.html("211e2dff"))

	if show_front_faces:
		_ensure_extrusion_texture()
		if extrusion_texture != null:
			draw_texture(extrusion_texture, Vector2.ZERO)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if not _is_solid(empty_cell):
				_draw_hole_corners(empty_cell, _cell_rect(empty_cell))

	# Hole Corner patches intentionally extend past their vertex, but pixels below
	# a downward-facing block belong to the front wall. Clean only those face
	# rectangles, then redraw the extrusion there. This removes gray floor rims
	# without changing the approved Hole Corner image or its -3 px anchor.
	_draw_front_face_occlusion()

	if hovered_cell.x >= 0 and hovered_cell.y >= 0 and hovered_cell.x < MAP_SIZE.x and hovered_cell.y < MAP_SIZE.y:
		draw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(1, 1, 1, 0.42), false, 1.5)

func _draw_front_face_occlusion() -> void:
	if not show_front_faces or extrusion_texture == null:
		return
	var texture_size := extrusion_texture.get_size()
	for cell_y in range(MAP_SIZE.y):
		for cell_x in range(MAP_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			if not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):
				continue
			var face_rect := Rect2(
				Vector2(cell_x * CELL_SIZE, (cell_y + 1) * CELL_SIZE),
				Vector2(CELL_SIZE, front_depth)
			)
			var clipped := face_rect.intersection(Rect2(Vector2.ZERO, texture_size))
			if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
				continue
			draw_rect(clipped, CAVE_COLOR)
			draw_texture_rect_region(extrusion_texture, clipped, clipped)

func _draw_hole_corners(empty_cell: Vector2i, rect: Rect2) -> void:
	var rules := [
		[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],
		[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],
		[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],
		[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],
	]
	for rule_value: Variant in rules:
		var rule: Array = rule_value
		var first: Vector2i = rule[0]
		var second: Vector2i = rule[1]
		var diagonal: Vector2i = rule[2]
		var frame: int = rule[3]
		if not _is_solid(empty_cell + first) or not _is_solid(empty_cell + second) or not _is_solid(empty_cell + diagonal):
			continue
		var owner_type := _cell_type(empty_cell + diagonal)
		var textures := _corner_textures_for_cell(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		var patch_rect := _hole_corner_patch_rect(rect, frame)
		# Adjacent straight borders remain untouched. The Hole Corner is only an
		# overlay transition and no longer paints mass bands over its neighbours.
		# But since it has a transparent cave background, we must erase the solid
		# rock square corner underneath it so the rounded silhouette is visible!
		draw_rect(patch_rect, CAVE_COLOR)
		draw_texture_rect(textures[frame], patch_rect, false)

func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# The authored curve is centered in the full stamp. This offset places its
	# original vertex at the same world-grid joint while retaining overscan on
	# both sides of the curve.
	var position := rect.position - Vector2(HOLE_VERTEX_OFFSET, HOLE_VERTEX_OFFSET)
	match frame:
		1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET, rect.position.y - HOLE_VERTEX_OFFSET)
		2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET, rect.end.y - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET)
		3: position = Vector2(rect.position.x - HOLE_VERTEX_OFFSET, rect.end.y - CORNER_PATCH_SIZE + HOLE_VERTEX_OFFSET)
	return Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))

func _border_image_for_cell(cell_type: int) -> Image:
	return border_images.get(_tier_for_cell_type(cell_type)) as Image

func _restore_hole_corner_border_bands(rect: Rect2, patch_rect: Rect2, frame: int, owner_type: int) -> void:
	if mass_texture == null:
		return
	var owner_border := _border_image_for_cell(owner_type)
	if owner_border == null:
		return
	var depth := float(CORNER_BUILDER.border_depth(owner_border))
	match frame:
		0:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.position.y - depth), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2.ZERO, Vector2(depth, patch_rect.size.y)))
		1:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.position.y - depth), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2(LOGICAL_SIZE - int(depth), 0), Vector2(depth, patch_rect.size.y)))
		2:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.end.y), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2(LOGICAL_SIZE - int(depth), 0), Vector2(depth, patch_rect.size.y)))
		3:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(patch_rect.position.x, rect.end.y), Vector2(patch_rect.size.x, depth)), Rect2(Vector2.ZERO, Vector2(patch_rect.size.x, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, patch_rect.position.y), Vector2(depth, patch_rect.size.y)), Rect2(Vector2.ZERO, Vector2(depth, patch_rect.size.y)))

func _cell_from_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _brush_cell_type() -> int:
	match preview_brush:
		PreviewBrush.EASY:
			return CellType.EASY
		PreviewBrush.MEDIUM:
			return CellType.MEDIUM
		PreviewBrush.HARD:
			return CellType.HARD
		PreviewBrush.UNMINEABLE:
			return CellType.UNMINEABLE
		PreviewBrush.GEMS:
			return CellType.GEMS
		PreviewBrush.CRACKS:
			return CellType.CRACKS
		_:
			return CellType.EMPTY

func _apply_edit(cell: Vector2i, button: int) -> void:
	if cell.x <= 0 or cell.y <= 0 or cell.x >= MAP_SIZE.x - 1 or cell.y >= MAP_SIZE.y - 1:
		return
	if button == MOUSE_BUTTON_RIGHT:
		cells[cell] = CellType.EMPTY
	else:
		cells[cell] = _brush_cell_type()
	_mark_extrusion_dirty()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		hovered_cell = _cell_from_position(motion.position)
		if dragging and hovered_cell != last_drag_cell:
			last_drag_cell = hovered_cell
			_apply_edit(hovered_cell, drag_button)
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mouse.pressed:
			dragging = true
			drag_button = mouse.button_index
			last_drag_cell = _cell_from_position(mouse.position)
			_apply_edit(last_drag_cell, drag_button)
		else:
			dragging = false
			last_drag_cell = Vector2i(-1, -1)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		dragging = false
		hovered_cell = Vector2i(-1, -1)
		queue_redraw()
