extends Node

func _ready() -> void:
	var path := "res://tools/sprite_lab/dome_material_workbench.gd"
	var text := FileAccess.get_file_as_string(path)
	var replacements := [
		[
			"const RUNTIME_BORDER_PATHS := {\n\t\"unmineable\": RUNTIME_DIR + \"/Unmineable_Border_Atlas.png\",\n\t\"easy\": RUNTIME_DIR + \"/Easy_Border_Atlas.png\",\n\t\"medium\": RUNTIME_DIR + \"/Medium_Border_Atlas.png\",\n\t\"hard\": RUNTIME_DIR + \"/Hard_Border_Atlas.png\",\n}\n",
			"const RUNTIME_BORDER_PATHS := {\n\t\"unmineable\": RUNTIME_DIR + \"/Unmineable_Border_Atlas.png\",\n\t\"easy\": RUNTIME_DIR + \"/Easy_Border_Atlas.png\",\n\t\"medium\": RUNTIME_DIR + \"/Medium_Border_Atlas.png\",\n\t\"hard\": RUNTIME_DIR + \"/Hard_Border_Atlas.png\",\n}\nconst RUNTIME_INSIDE_CORNER_PATHS := {\n\t\"unmineable\": RUNTIME_DIR + \"/Unmineable_Inside_Corners.png\",\n\t\"easy\": RUNTIME_DIR + \"/Easy_Inside_Corners.png\",\n\t\"medium\": RUNTIME_DIR + \"/Medium_Inside_Corners.png\",\n\t\"hard\": RUNTIME_DIR + \"/Hard_Inside_Corners.png\",\n}\n"
		],
		[
			"export_button.text = \"EXPORT 4 BORDER ATLASES\"",
			"export_button.text = \"EXPORT BORDERS + CORNERS\""
		],
		[
			"instruction_label.text = \"Paint the one dark full tile used under every rock type.\" if current_mode == \"mass\" else \"Paint only the CYAN TOP BAND. The game rotates this one stamp for all four directions and all corner masks.\"",
			"instruction_label.text = \"Paint the one dark full tile used under every rock type.\" if current_mode == \"mass\" else \"Paint only the CYAN TOP BAND. The game rotates it for four sides, convex joins and dirt-facing inside-corner connectors.\""
		],
		[
			"\t\tvar atlas := _build_border_atlas(border_images[tier])\n\t\tresult = atlas.save_png(String(RUNTIME_BORDER_PATHS[tier]))\n\t_save_sources()\n\tstatus_label.text = \"Exported universal mass plus Unmineable, Easy, Medium and Hard 16-mask border atlases.\" if result == OK else \"Runtime export failed: %s\" % error_string(result)",
			"\t\tvar atlas := _build_border_atlas(border_images[tier])\n\t\tresult = atlas.save_png(String(RUNTIME_BORDER_PATHS[tier]))\n\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(border_images[tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))\n\t_save_sources()\n\tstatus_label.text = \"Exported universal mass, four 16-mask border atlases and four inside-corner atlases.\" if result == OK else \"Runtime export failed: %s\" % error_string(result)"
		]
	]
	for replacement_value in replacements:
		var replacement: Array = replacement_value
		if not text.contains(String(replacement[0])):
			push_error("Inside-corner export patch could not find expected text")
			get_tree().quit(1)
			return
		text = text.replace(String(replacement[0]), String(replacement[1]))

	var insertion_marker := "func _find_brightest_color(image: Image) -> Color:\n"
	var helpers := """func _border_depth(top_border: Image) -> int:
	var deepest := -1
	for y in range(LOGICAL_SIZE):
		for x in range(LOGICAL_SIZE):
			if top_border.get_pixel(x, y).a > 0.05:
				deepest = maxi(deepest, y)
	return clampi(deepest + 1, 3, 14)

func _average_border_row(image: Image, row: int) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for x in range(LOGICAL_SIZE):
		var color := image.get_pixel(x, clampi(row, 0, LOGICAL_SIZE - 1))
		if color.a > 0.05:
			total += color
			count += 1
	if count == 0:
		return Color.TRANSPARENT
	return total / float(count)

func _make_inside_corner_top_left(top_border: Image) -> Image:
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := _border_depth(top_border)
	for y in range(depth + 1):
		for x in range(depth + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).length()
			if distance > float(depth):
				continue
			var color := _average_border_row(top_border, clampi(floori(distance), 0, depth - 1))
			if color.a > 0.05:
				result.set_pixel(x, y, color)
	return result

func _build_inside_corner_atlas(top_border: Image) -> Image:
	var atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var top_left := _make_inside_corner_top_left(top_border)
	for frame in range(4):
		var corner := _rotate_quarters(top_left, frame)
		corner.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		var atlas_cell := Vector2i(frame % 2, frame / 2)
		atlas.blit_rect(corner, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), atlas_cell * TILE_SIZE)
	return atlas

"""
	if not text.contains(insertion_marker):
		push_error("Inside-corner export patch could not find helper insertion marker")
		get_tree().quit(1)
		return
	text = text.replace(insertion_marker, helpers + insertion_marker)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write inside-corner export patch")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Inside-corner export atlases installed")
	get_tree().quit()
