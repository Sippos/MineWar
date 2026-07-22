extends Node

const SOURCE_PATH := "res://GemOverlay.png"
const OUTPUT_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_gem_overlay_atlas.png"
const CELL_SIZE := 64
const COLS := 4
const ROWS := 2

func _ready() -> void:
	var source := Image.load_from_file(SOURCE_PATH)
	if source == null or source.is_empty():
		push_error("GEM_OVERLAY_CROP_LOAD_FAILED")
		get_tree().quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(CELL_SIZE * COLS, CELL_SIZE * ROWS, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for row in range(ROWS):
		for col in range(COLS):
			var x0 := int(round(float(source.get_width()) * float(col) / float(COLS)))
			var x1 := int(round(float(source.get_width()) * float(col + 1) / float(COLS)))
			var y0 := int(round(float(source.get_height()) * float(row) / float(ROWS)))
			var y1 := int(round(float(source.get_height()) * float(row + 1) / float(ROWS)))
			var quadrant := source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
			var cleaned := _remove_checkerboard(quadrant)
			var bounds := _alpha_bounds(cleaned)
			if bounds.size.x <= 0 or bounds.size.y <= 0:
				push_error("GEM_OVERLAY_EMPTY_QUADRANT %d,%d" % [col, row])
				continue
			var crop := cleaned.get_region(bounds)
			var subtle := row == 1 and col == 2
			var target := _fit_nearest(crop, 28 if subtle else 60, 28 if subtle else 60)
			var placement := _placement(col, row, target.get_width(), target.get_height())
			atlas.blit_rect(target, Rect2i(Vector2i.ZERO, target.get_size()), placement)
			print("GEM_OVERLAY_CELL ", col, ",", row, " bounds=", bounds, " output=", target.get_size(), " placement=", placement)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var error := atlas.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("GEM_OVERLAY_CROP_SAVE_FAILED %d" % error)
		get_tree().quit(2)
		return
	print("GEM_OVERLAY_CROP_OK ", OUTPUT_PATH, " size=", atlas.get_width(), "x", atlas.get_height())
	get_tree().quit(0)

func _is_checker_pixel(color: Color) -> bool:
	var minimum := minf(color.r, minf(color.g, color.b))
	var maximum := maxf(color.r, maxf(color.g, color.b))
	return minimum > 0.78 and maximum - minimum < 0.065

func _remove_checkerboard(image: Image) -> Image:
	var width := image.get_width()
	var height := image.get_height()
	var foreground := PackedByteArray()
	foreground.resize(width * height)
	for y in range(height):
		for x in range(width):
			if not _is_checker_pixel(image.get_pixel(x, y)):
				foreground[y * width + x] = 1
	# Preserve bright crystal glints only when they are attached to actual art.
	var keep := PackedByteArray()
	keep.resize(width * height)
	const RADIUS := 3
	for y in range(height):
		for x in range(width):
			var found := false
			for dy in range(-RADIUS, RADIUS + 1):
				if found:
					break
				for dx in range(-RADIUS, RADIUS + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or nx >= width or ny < 0 or ny >= height:
						continue
					if foreground[ny * width + nx] != 0:
						found = true
						break
			if found:
				keep[y * width + x] = 1
	var cleaned := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var color: Color = image.get_pixel(x, y)
			color.a = 1.0 if keep[y * width + x] != 0 else 0.0
			cleaned.set_pixel(x, y, color)
	return cleaned

func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _fit_nearest(image: Image, max_width: int, max_height: int) -> Image:
	var scale := minf(float(max_width) / float(image.get_width()), float(max_height) / float(image.get_height()))
	var width := maxi(1, int(round(float(image.get_width()) * scale)))
	var height := maxi(1, int(round(float(image.get_height()) * scale)))
	var result := image.duplicate()
	result.resize(width, height, Image.INTERPOLATE_NEAREST)
	return result

func _placement(col: int, row: int, width: int, height: int) -> Vector2i:
	var x := col * CELL_SIZE + int(floor(float(CELL_SIZE - width) * 0.5))
	var y := row * CELL_SIZE + int(floor(float(CELL_SIZE - height) * 0.5))
	if col == 2 and row == 0:
		x = col * CELL_SIZE
	elif col == 3 and row == 0:
		x = col * CELL_SIZE + CELL_SIZE - width
	return Vector2i(x, y)
