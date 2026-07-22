extends Control

const CORNER_BUILDER = preload("res://tools/sprite_lab/dome_corner_builder.gd")

const MAP_SIZE := Vector2i(12, 8)
const CELL_SIZE := 32
const LOGICAL_SIZE := 32
const TILE_SIZE := 64
const CORNER_PATCH_SIZE := 14
const HOLE_CORNER_ORIGIN := Vector2i(LOGICAL_SIZE - CORNER_PATCH_SIZE, LOGICAL_SIZE - CORNER_PATCH_SIZE)
const CAVE_COLOR := Color("111725")
# The editable wedge may be 14 logical pixels, but only the bright rim at the
# ends of the straight strips must be masked. A shallow mask avoids square bites.
const CAVE_CORNER_RADIUS := 10.0
const BORDER_MASK_DEPTH := 4.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

enum CellType {
	EMPTY,
	ROCK,
	UNMINEABLE,
}

var mass_image: Image
var mass_texture: ImageTexture
var selected_border_image: Image
var unmineable_border_image: Image
var selected_corner_image: Image
var unmineable_corner_image: Image
var selected_convex_image: Image
var unmineable_convex_image: Image
var selected_composite_textures: Array[ImageTexture] = []
var unmineable_composite_textures: Array[ImageTexture] = []
var selected_inside_corner_textures: Array[ImageTexture] = []
var unmineable_inside_corner_textures: Array[ImageTexture] = []
var cells: Dictionary = {}
var dragging := false
var drag_button := MOUSE_BUTTON_LEFT
var last_drag_cell := Vector2i(-1, -1)
var hovered_cell := Vector2i(-1, -1)
var rounded_light_corners := true
var rock_lip_outside_cell := false

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reset_layout()

func set_material_images(new_mass_image: Image, selected_top_border: Image, unmineable_top_border: Image, selected_top_left_corner: Image, unmineable_top_left_corner: Image, selected_top_left_convex: Image, unmineable_top_left_convex: Image) -> void:
	mass_image = new_mass_image.duplicate()
	mass_texture = ImageTexture.create_from_image(mass_image)
	selected_border_image = selected_top_border.duplicate()
	unmineable_border_image = unmineable_top_border.duplicate()
	selected_corner_image = selected_top_left_corner.duplicate()
	unmineable_corner_image = unmineable_top_left_corner.duplicate()
	selected_convex_image = selected_top_left_convex.duplicate()
	unmineable_convex_image = unmineable_top_left_convex.duplicate()
	_rebuild_material_textures()

func set_rounded_light_corners(value: bool) -> void:
	rounded_light_corners = value
	_rebuild_material_textures()

func set_rock_lip_outside_cell(value: bool) -> void:
	rock_lip_outside_cell = value
	queue_redraw()

func _rebuild_material_textures() -> void:
	if mass_image == null or selected_border_image == null or unmineable_border_image == null:
		return
	if rounded_light_corners:
		selected_composite_textures = _build_logical_composite_textures(mass_image, selected_border_image, selected_convex_image)
		unmineable_composite_textures = _build_logical_composite_textures(mass_image, unmineable_border_image, unmineable_convex_image)
	else:
		selected_composite_textures = _build_square_composite_textures(mass_image, selected_border_image)
		unmineable_composite_textures = _build_square_composite_textures(mass_image, unmineable_border_image)
	selected_inside_corner_textures = _build_vertex_hole_textures(mass_image, selected_border_image, selected_corner_image)
	unmineable_inside_corner_textures = _build_vertex_hole_textures(mass_image, unmineable_border_image, unmineable_corner_image)
	queue_redraw()
func _build_authored_corner_textures(source: Image) -> Array[ImageTexture]:
	return _build_vertex_hole_textures(mass_image, selected_border_image, source)

func _build_vertex_hole_textures(_mass: Image, _top_border: Image, hole_source: Image) -> Array[ImageTexture]:
	var source_patch := Image.create(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE, false, Image.FORMAT_RGBA8)
	source_patch.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			source_patch.set_pixel(x, y, hole_source.get_pixel(x, y))
	var result: Array[ImageTexture] = []
	for frame in range(4):
		result.append(ImageTexture.create_from_image(_rotate_corner_patch(source_patch, frame)))
	return result
func _rotate_vertex_composite(source: Image, turns: int) -> Image:
	# The 2x2 composite's terrain vertex lies between pixels 31 and 32. Pixel
	# indices therefore rotate around (31.5, 31.5), using the normal size - 1
	# quarter-turn mapping. Rotating indices around integer 32 shifts the 90°,
	# 180° and 270° Hole Corner frames by one logical pixel.
	var normalized := posmod(turns, 4)
	var size := source.get_width()
	var result := Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var destination := Vector2i(x, y)
			match normalized:
				1: destination = Vector2i(size - 1 - y, x)
				2: destination = Vector2i(size - 1 - x, size - 1 - y)
				3: destination = Vector2i(y, size - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
func _build_diagonal_hole_textures(edge_joint_source: Image) -> Array[ImageTexture]:
	# Start with the exact Edge Joint source. Inside its authored 14x14 patch,
	# transparent pixels are the cave cutout; make them opaque cave colour so the
	# overlay can replace pixels from the diagonal solid tile beneath it.
	var replacement := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	replacement.fill(Color.TRANSPARENT)
	for y in range(CORNER_PATCH_SIZE):
		for x in range(CORNER_PATCH_SIZE):
			var color := edge_joint_source.get_pixel(x, y)
			replacement.set_pixel(x, y, CAVE_COLOR if color.a <= 0.05 else color)

	var result: Array[ImageTexture] = []
	for frame in range(4):
		# Empty-cell TL/TR/BR/BL corners are owned by the diagonal solid tile's
		# BR/BL/TL/TR corner respectively: Edge Joint turns 2/3/0/1.
		var turn := posmod(frame + 2, 4)
		var overlay := CORNER_BUILDER.rotate_quarters(replacement, turn)
		result.append(ImageTexture.create_from_image(overlay))
	return result
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

func _build_logical_composite_textures(base: Image, top_border: Image, edge_joint: Image) -> Array[ImageTexture]:
	# The live cave uses 32x32 cells. Keep solid tiles at their native logical
	# resolution so they use the same one-logical-pixel sampling as the 64x64
	# two-cell Hole Corner overlays. Upscaling to 64 and shrinking back to 32
	# introduces a half-texel sampling difference at the shared vertex.
	var result: Array[ImageTexture] = []
	for mask in range(16):
		var tile := CORNER_BUILDER.build_composite_tile(base, top_border, mask, edge_joint)
		result.append(ImageTexture.create_from_image(tile))
	return result

func _build_square_composite_textures(base: Image, top_border: Image) -> Array[ImageTexture]:
	var directions: Array[Image] = []
	for turn in range(4):
		directions.append(CORNER_BUILDER.rotate_quarters(top_border, turn))
	var result: Array[ImageTexture] = []
	for mask in range(16):
		var tile := base.duplicate()
		for direction_index in range(4):
			if (mask & (1 << direction_index)) != 0:
				tile.blend_rect(directions[direction_index], Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)), Vector2i.ZERO)
		result.append(ImageTexture.create_from_image(tile))
	return result

func reset_layout() -> void:
	cells.clear()
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			cells[cell] = CellType.UNMINEABLE if _is_outer_ring(cell) else CellType.ROCK
	for y in range(2, 6):
		for x in range(3, 9):
			cells[Vector2i(x, y)] = CellType.EMPTY
	cells[Vector2i(3, 2)] = CellType.ROCK
	cells[Vector2i(7, 4)] = CellType.ROCK
	queue_redraw()

func _is_outer_ring(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1

func _cell_type(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return CellType.UNMINEABLE
	return int(cells.get(cell, CellType.ROCK))

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

func _composite_textures_for(cell_type: int) -> Array[ImageTexture]:
	return unmineable_composite_textures if cell_type == CellType.UNMINEABLE else selected_composite_textures

func _inside_corner_textures_for(cell_type: int) -> Array[ImageTexture]:
	return unmineable_inside_corner_textures if cell_type == CellType.UNMINEABLE else selected_inside_corner_textures

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
			var textures := _composite_textures_for(cell_type)
			if mask < textures.size() and textures[mask] != null:
				draw_texture_rect(textures[mask], _cell_rect(cell), false)
			else:
				draw_rect(_cell_rect(cell), Color.html("211e2dff"))

	# Hole Corners belong to the corner of an EMPTY cell. The diagonal solid
	# block chooses the material, while short masks remove the square endpoints
	# of the two neighbouring straight borders.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var empty_cell := Vector2i(x, y)
			if not _is_solid(empty_cell):
				_draw_hole_corners(empty_cell, _cell_rect(empty_cell))

	if hovered_cell.x >= 0 and hovered_cell.y >= 0 and hovered_cell.x < MAP_SIZE.x and hovered_cell.y < MAP_SIZE.y:
		draw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(1, 1, 1, 0.42), false, 1.5)

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
		var textures := _inside_corner_textures_for(owner_type)
		if frame >= textures.size() or textures[frame] == null:
			continue
		var patch_rect := _hole_corner_patch_rect(rect, frame)
		_restore_hole_corner_border_bands(rect, patch_rect, frame)
		draw_texture_rect(textures[frame], patch_rect, false)
func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
	# Canonical patch sits three logical pixels outward from the terrain vertex.
	# This is the opposite one-pixel correction from the previous close vertex-2 anchor.
	var position := rect.position - Vector2(3.0, 3.0)
	match frame:
		1: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 3.0, rect.position.y - 3.0)
		2: position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 3.0, rect.end.y - CORNER_PATCH_SIZE + 3.0)
		3: position = Vector2(rect.position.x - 3.0, rect.end.y - CORNER_PATCH_SIZE + 3.0)
	return Rect2(position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
func _restore_hole_corner_border_bands(rect: Rect2, patch_rect: Rect2, frame: int) -> void:
	if mass_texture == null:
		return
	var depth := float(CORNER_BUILDER.border_depth(selected_border_image))
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
func _border_depth_for(owner_type: int) -> int:
	var image: Image = unmineable_border_image if owner_type == CellType.UNMINEABLE else selected_border_image
	if image == null or image.is_empty():
		return 2
	var deepest := -1
	for y in range(mini(LOGICAL_SIZE, image.get_height())):
		for x in range(mini(LOGICAL_SIZE, image.get_width())):
			if image.get_pixel(x, y).a > 0.05:
				deepest = maxi(deepest, y)
	return clampi(deepest + 1, 1, CORNER_PATCH_SIZE)

func _mask_hole_corner_border_bands(rect: Rect2, _patch_rect: Rect2, frame: int, owner_type: int) -> void:
	# Remove only the square ends of the two straight borders, restoring the
	# original dirt mass underneath. Drawing cave colour here caused the black
	# notches that looked like a persistent one-pixel offset.
	if mass_texture == null:
		return
	var depth := float(_border_depth_for(owner_type))
	var cut := float(CORNER_PATCH_SIZE - 4)
	match frame:
		0:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x, rect.position.y - depth), Vector2(cut, depth)), Rect2(Vector2(0, LOGICAL_SIZE - int(depth)), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, rect.position.y), Vector2(depth, cut)), Rect2(Vector2(LOGICAL_SIZE - int(depth), 0), Vector2(depth, cut)))
		1:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x - cut, rect.position.y - depth), Vector2(cut, depth)), Rect2(Vector2(LOGICAL_SIZE - int(cut), LOGICAL_SIZE - int(depth)), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, rect.position.y), Vector2(depth, cut)), Rect2(Vector2(0, 0), Vector2(depth, cut)))
		2:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x - cut, rect.end.y), Vector2(cut, depth)), Rect2(Vector2(LOGICAL_SIZE - int(cut), 0), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.end.x, rect.end.y - cut), Vector2(depth, cut)), Rect2(Vector2(0, LOGICAL_SIZE - int(cut)), Vector2(depth, cut)))
		3:
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x, rect.end.y), Vector2(cut, depth)), Rect2(Vector2(0, 0), Vector2(cut, depth)))
			draw_texture_rect_region(mass_texture, Rect2(Vector2(rect.position.x - depth, rect.end.y - cut), Vector2(depth, cut)), Rect2(Vector2(LOGICAL_SIZE - int(depth), LOGICAL_SIZE - int(cut)), Vector2(depth, cut)))

func _cell_from_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _apply_edit(cell: Vector2i, button: int) -> void:
	if cell.x <= 0 or cell.y <= 0 or cell.x >= MAP_SIZE.x - 1 or cell.y >= MAP_SIZE.y - 1:
		return
	if button == MOUSE_BUTTON_LEFT:
		cells[cell] = CellType.EMPTY
	elif button == MOUSE_BUTTON_RIGHT:
		cells[cell] = CellType.ROCK
	queue_redraw()

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
