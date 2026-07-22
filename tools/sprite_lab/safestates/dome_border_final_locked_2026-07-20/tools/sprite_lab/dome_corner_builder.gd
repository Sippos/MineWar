extends RefCounted

## Shared pixel generator used by both the workbench preview and runtime export.
##
## The normal terrain set has three authored pieces:
## 1. one straight top border, rotated for all four sides;
## 2. one top-left edge joint, rotated where two straight sides meet;
## 3. one top-left concave connector, rotated inside empty tunnel cells.

const LOGICAL_SIZE := 32
const TILE_SIZE := 64
const ATLAS_SIZE := 256
const CORNER_EDIT_SIZE := 14
const CORNER_RADIUS_MIN := 6
const CORNER_RADIUS_MAX := 11

static func rotate_quarters(source: Image, turns: int) -> Image:
	var normalized_turns := posmod(turns, 4)
	var width := source.get_width()
	var height := source.get_height()
	if width != height:
		push_error("rotate_quarters expects a square image")
		return source.duplicate()
	var size := width
	var result: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var destination := Vector2i(x, y)
			match normalized_turns:
				1: destination = Vector2i(size - 1 - y, x)
				2: destination = Vector2i(size - 1 - x, size - 1 - y)
				3: destination = Vector2i(y, size - 1 - x)
			result.set_pixelv(destination, source.get_pixel(x, y))
	return result
static func border_depth(top_border: Image) -> int:
	var deepest := -1
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			if top_border.get_pixel(x, y).a > 0.05:
				deepest = maxi(deepest, y)
	return clampi(deepest + 1, 3, CORNER_EDIT_SIZE)

static func average_border_row(image: Image, row: int) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	var safe_row := clampi(row, 0, LOGICAL_SIZE - 1)
	for x in range(LOGICAL_SIZE):
		var color := image.get_pixel(x, safe_row)
		if color.a > 0.05:
			total += color
			count += 1
	if count > 0:
		return total / float(count)
	for offset in range(1, LOGICAL_SIZE):
		for fallback_row in [safe_row - offset, safe_row + offset]:
			if fallback_row < 0 or fallback_row >= LOGICAL_SIZE:
				continue
			for x in range(LOGICAL_SIZE):
				var fallback := image.get_pixel(x, fallback_row)
				if fallback.a > 0.05:
					total += fallback
					count += 1
			if count > 0:
				return total / float(count)
	return Color.TRANSPARENT

static func build_square_composite_tile(mass_image: Image, top_border: Image, mask: int) -> Image:
	var tile := mass_image.duplicate()
	tile.convert(Image.FORMAT_RGBA8)
	if tile.get_width() != LOGICAL_SIZE or tile.get_height() != LOGICAL_SIZE:
		tile.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	var directions: Array[Image] = []
	for turn in range(4):
		directions.append(rotate_quarters(top_border, turn))
	for direction_index in range(4):
		if (mask & (1 << direction_index)) != 0:
			tile.blend_rect(
				directions[direction_index],
				Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)),
				Vector2i.ZERO
			)
	return tile

static func make_edge_joint_top_left(mass_image: Image, top_border: Image) -> Image:
	## Creates a clean starter joint. The source is a replacement patch: pixels
	## outside the rounded solid silhouette are transparent and reveal the cave.
	var square_tile := build_square_composite_tile(mass_image, top_border, 1 | 8)
	var result: Image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := border_depth(top_border)
	var radius := clampi(depth, CORNER_RADIUS_MIN, CORNER_RADIUS_MAX)
	var rim_thickness := clampi(int(ceil(float(depth) * 0.72)), 3, radius)
	var center := Vector2(float(radius) + 0.5, float(radius) + 0.5)

	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			var sample := Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance := sample.distance_to(center)
			if distance > float(radius):
				# Cave cutout: this removes the square tip where the two straight
				# borders would otherwise fail to make a rounded turn.
				continue
			var color := square_tile.get_pixel(x, y)
			var inward_depth := float(radius) - distance
			if inward_depth < float(rim_thickness):
				var source_row := clampi(floori(inward_depth), 0, depth - 1)
				var rim_color := average_border_row(top_border, source_row)
				if rim_color.a > 0.05:
					color = rim_color
			result.set_pixel(x, y, color)
	return result

# Compatibility alias for older patch scripts and saved editor code.
static func make_convex_corner_top_left(mass_image: Image, top_border: Image) -> Image:
	return make_edge_joint_top_left(mass_image, top_border)

static func build_composite_tile(mass_image: Image, top_border: Image, mask: int, top_left_joint: Image = null) -> Image:
	var tile := build_square_composite_tile(mass_image, top_border, mask)
	if (mask & 1) != 0 and (mask & 8) != 0:
		_apply_edge_joint(tile, mass_image, top_border, top_left_joint, 0)
	if (mask & 1) != 0 and (mask & 2) != 0:
		_apply_edge_joint(tile, mass_image, top_border, top_left_joint, 1)
	if (mask & 4) != 0 and (mask & 2) != 0:
		_apply_edge_joint(tile, mass_image, top_border, top_left_joint, 2)
	if (mask & 4) != 0 and (mask & 8) != 0:
		_apply_edge_joint(tile, mass_image, top_border, top_left_joint, 3)
	return tile

static func build_composite_atlas(mass_image: Image, top_border: Image, top_left_joint: Image = null) -> Image:
	var atlas := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for mask in range(16):
		var tile := build_composite_tile(mass_image, top_border, mask, top_left_joint)
		tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(
			tile,
			Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)),
			Vector2i(mask % 4, mask / 4) * TILE_SIZE
		)
	return atlas

static func build_composite_textures(mass_image: Image, top_border: Image, top_left_joint: Image = null) -> Array[ImageTexture]:
	var result: Array[ImageTexture] = []
	for mask in range(16):
		var tile := build_composite_tile(mass_image, top_border, mask, top_left_joint)
		tile.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		result.append(ImageTexture.create_from_image(tile))
	return result

static func make_hole_corner_top_left(mass_image: Image, top_border: Image, edge_joint: Image = null) -> Image:
	## Build the opposite topology from the exact authored Edge Joint boundary.
	## The old color-difference heuristic preserved unrelated interior pixels,
	## producing the visible hook/stub where Hole Corners met straight borders.
	var joint: Image = edge_joint
	if joint == null or joint.is_empty():
		joint = make_edge_joint_top_left(mass_image, top_border)
	joint = joint.duplicate()
	joint.convert(Image.FORMAT_RGBA8)
	if joint.get_width() != LOGICAL_SIZE or joint.get_height() != LOGICAL_SIZE:
		joint.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	var mass: Image = mass_image.duplicate()
	mass.convert(Image.FORMAT_RGBA8)
	if mass.get_width() != LOGICAL_SIZE or mass.get_height() != LOGICAL_SIZE:
		mass.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)

	# Flood-fill only the transparent cave region connected to the authored
	# top-left origin. This is the side that becomes solid in the Hole Corner.
	var outside_lookup: Dictionary = {}
	var outside_points: Array[Vector2i] = []
	var pending: Array[Vector2i] = []
	if joint.get_pixel(0, 0).a <= 0.05:
		outside_lookup[Vector2i.ZERO] = true
		pending.append(Vector2i.ZERO)
	while not pending.is_empty():
		var point: Vector2i = pending.pop_front()
		outside_points.append(point)
		for direction_value: Variant in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var direction: Vector2i = direction_value as Vector2i
			var next_point: Vector2i = point + direction
			if next_point.x < 0 or next_point.y < 0 or next_point.x >= CORNER_EDIT_SIZE or next_point.y >= CORNER_EDIT_SIZE:
				continue
			if outside_lookup.has(next_point) or joint.get_pixelv(next_point).a > 0.05:
				continue
			outside_lookup[next_point] = true
			pending.append(next_point)

	var result: Image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for point: Vector2i in outside_points:
		result.set_pixelv(point, mass.get_pixelv(point))

	# Preserve one clean, continuous band of the authored Edge Joint pixels.
	# The distance is derived from the straight border depth, but intentionally
	# excludes deep interior decoration that caused disconnected protrusions.
	var band_thickness: float = maxf(3.5, float(border_depth(top_border)) * 0.42)
	for y in range(CORNER_EDIT_SIZE):
		for x in range(CORNER_EDIT_SIZE):
			var point := Vector2i(x, y)
			var source_color: Color = joint.get_pixelv(point)
			if source_color.a <= 0.05:
				continue
			var nearest_distance := 999.0
			for outside_point: Vector2i in outside_points:
				nearest_distance = minf(nearest_distance, Vector2(point).distance_to(Vector2(outside_point)))
			if nearest_distance <= band_thickness:
				result.set_pixelv(point, source_color)
	return result

static func make_cave_corner_top_left(mass_image: Image, top_border: Image) -> Image:
	# Empty-space corner: solid rock occupies the quarter disk near the cell
	# corner, while the bright border follows the OUTER arc and connects the
	# two neighbouring straight border strips.
	var result: Image = Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := border_depth(top_border)
	var radius := clampi(depth + 3, 7, CORNER_EDIT_SIZE - 1)
	for y in range(radius + 1):
		for x in range(radius + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).length()
			if distance > float(radius):
				continue
			var inward_depth := float(radius) - distance
			var color: Color
			if inward_depth < float(depth):
				color = average_border_row(top_border, clampi(floori(inward_depth), 0, depth - 1))
			else:
				color = mass_image.get_pixel(clampi(x, 0, mass_image.get_width() - 1), clampi(y, 0, mass_image.get_height() - 1))
			if color.a > 0.05:
				result.set_pixel(x, y, color)
	for bridge in range(2):
		var edge_color := average_border_row(top_border, bridge)
		result.set_pixel(clampi(radius - bridge, 0, LOGICAL_SIZE - 1), 0, edge_color)
		result.set_pixel(0, clampi(radius - bridge, 0, LOGICAL_SIZE - 1), edge_color)
	return result

static func make_inside_corner_top_left(top_border: Image) -> Image:
	var fallback_mass := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	fallback_mass.fill(Color.html("211e2dff"))
	return make_cave_corner_top_left(fallback_mass, top_border)

static func build_inside_corner_atlas(top_border: Image) -> Image:
	var atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var top_left := make_inside_corner_top_left(top_border)
	for frame in range(4):
		var corner := rotate_quarters(top_left, frame)
		corner.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(
			corner,
			Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)),
			Vector2i(frame % 2, frame / 2) * TILE_SIZE
		)
	return atlas

static func build_inside_corner_textures(top_border: Image) -> Array[ImageTexture]:
	var result: Array[ImageTexture] = []
	var top_left := make_inside_corner_top_left(top_border)
	for frame in range(4):
		var corner := rotate_quarters(top_left, frame)
		corner.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		result.append(ImageTexture.create_from_image(corner))
	return result

static func _apply_edge_joint(tile: Image, mass_image: Image, top_border: Image, authored_top_left: Image, corner: int) -> void:
	var joint := authored_top_left
	if joint == null or joint.is_empty():
		joint = make_edge_joint_top_left(mass_image, top_border)

	# A joint is a replacement patch. Clearing the corner first allows its
	# transparent pixels to carve the rounded cave silhouette cleanly.
	for local_y in range(CORNER_EDIT_SIZE):
		for local_x in range(CORNER_EDIT_SIZE):
			tile.set_pixelv(_map_corner_point(local_x, local_y, corner), Color.TRANSPARENT)
	var rotated := rotate_quarters(joint, corner)
	tile.blend_rect(
		rotated,
		Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)),
		Vector2i.ZERO
	)

static func _map_corner_point(local_x: int, local_y: int, corner: int) -> Vector2i:
	match corner:
		1:
			return Vector2i(LOGICAL_SIZE - 1 - local_x, local_y)
		2:
			return Vector2i(LOGICAL_SIZE - 1 - local_x, LOGICAL_SIZE - 1 - local_y)
		3:
			return Vector2i(local_x, LOGICAL_SIZE - 1 - local_y)
		_:
			return Vector2i(local_x, local_y)
