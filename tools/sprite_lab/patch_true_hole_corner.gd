extends Node

const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"
const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"

func _ready() -> void:
	var ok := _patch_builder() and _patch_workbench() and _patch_preview()
	print("True opposite Hole Corner workflow installed" if ok else "Hole Corner patch failed")
	get_tree().quit(0 if ok else 1)

func _replace_required(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing hole-corner patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_builder() -> bool:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	var marker := "static func make_cave_corner_top_left(mass_image: Image, top_border: Image) -> Image:"
	if text.contains("static func make_hole_corner_top_left"):
		return true
	var function_text := "static func make_hole_corner_top_left(mass_image: Image, top_border: Image) -> Image:\n\t## Opposite of Edge Joint. This patch belongs to a solid block whose\n\t## diagonal neighbour is empty while both cardinal neighbours remain solid.\n\t## The corner is carved away, then a short L-shaped rim and curved arc are\n\t## drawn so the two neighbouring straight borders meet smoothly.\n\tvar result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tvar depth := border_depth(top_border)\n\tvar radius := clampi(depth + 2, 7, CORNER_EDIT_SIZE - 1)\n\tvar center := Vector2(float(radius) + 0.5, float(radius) + 0.5)\n\tfor y in range(CORNER_EDIT_SIZE):\n\t\tfor x in range(CORNER_EDIT_SIZE):\n\t\t\tvar sample := Vector2(float(x) + 0.5, float(y) + 0.5)\n\t\t\tvar distance := sample.distance_to(center)\n\t\t\t# The outer top-left side is the diagonal cave cutout.\n\t\t\tif distance > float(radius):\n\t\t\t\tcontinue\n\t\t\tvar color := mass_image.get_pixel(clampi(x, 0, mass_image.get_width() - 1), clampi(y, 0, mass_image.get_height() - 1))\n\t\t\tvar inward_depth := float(radius) - distance\n\t\t\tif inward_depth < float(depth):\n\t\t\t\tcolor = average_border_row(top_border, clampi(floori(inward_depth), 0, depth - 1))\n\t\t\tresult.set_pixel(x, y, color)\n\t# Unlike the exposed Edge Joint, this opposite turn needs only short rim\n\t# segments near the grid vertex. They connect to borders in neighbouring cells.\n\tfor offset in range(radius + 1):\n\t\tfor thickness in range(mini(depth, CORNER_EDIT_SIZE)):\n\t\t\tvar row_color := average_border_row(top_border, clampi(thickness, 0, depth - 1))\n\t\t\tif offset <= radius and thickness <= offset:\n\t\t\t\tresult.set_pixel(offset, thickness, row_color)\n\t\t\t\tresult.set_pixel(thickness, offset, row_color)\n\treturn result\n\n"
	if not text.contains(marker):
		push_error("Builder insertion marker missing")
		return false
	text = text.replace(marker, function_text + marker)
	return _write(BUILDER_PATH, text)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _replace_required(
		text,
		"\t_add_mode_button(controls, \"convex\", \"EDGE JOINT • one top-left turn\")\n",
		"\t_add_mode_button(controls, \"convex\", \"EDGE JOINT • exposed block turn\")\n\t_add_mode_button(controls, \"corner\", \"HOLE CORNER • opposite diagonal cutout\")\n",
		"hole corner button"
	)
	if text.is_empty(): return false
	text = text.replace(
		"Each material has one straight border and one EDGE JOINT. The same joint is rotated for isolated blocks, pillars, room corners and tunnel turns.",
		"Each material has a straight border, an EDGE JOINT for two exposed sides, and a separate opposite HOLE CORNER for an empty diagonal."
	)
	var old_loader := "func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\t# CAVE CORNER inside an empty cell, opposite the solid-cell edge joint.\n\tvar editable_path := SOURCE_DIR + \"/%s_cave_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tcorner = CORNER_BUILDER.make_cave_corner_top_left(mass_image, fallback_border)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner"
	var new_loader := "func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\t# Opposite HOLE CORNER: replacement patch on the diagonal solid block.\n\tvar editable_path := SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tcorner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, fallback_border)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner"
	text = _replace_required(text, old_loader, new_loader, "hole corner loader")
	if text.is_empty(): return false
	var old_base := "func _make_cave_base() -> Image:\n\tvar image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\timage.fill(Color.html(\"111725ff\"))\n\treturn image"
	var new_base := "func _make_cave_base() -> Image:\n\t# Base for the Hole Corner replacement patch: normal dark mass outside the\n\t# authored corner and cave colour beneath transparent cutout pixels.\n\tvar image := mass_image.duplicate()\n\tfor y in range(14):\n\t\tfor x in range(14):\n\t\t\timage.set_pixel(x, y, Color.html(\"111725ff\"))\n\treturn image"
	text = _replace_required(text, old_base, new_base, "hole corner editor base")
	if text.is_empty(): return false
	text = text.replace(
		"return \"%s CAVE CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()",
		"return \"%s HOLE CORNER • AUTHOR TOP-LEFT OPPOSITE TURN\" % current_tier.to_upper()"
	)
	text = text.replace(
		"instruction_label.text = \"Paint the TOP-LEFT corner INSIDE EMPTY CAVE SPACE. Its curved bright rim must connect the top and left straight borders; the game rotates it for the other three hole corners.\"",
		"instruction_label.text = \"Paint the TOP-LEFT opposite HOLE CORNER on the diagonal solid block. It must carve the corner and connect the two neighbouring border endpoints.\""
	)
	text = text.replace(
		"result = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_cave_corner_top_left_32.png\" % tier)",
		"result = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_hole_corner_top_left_32.png\" % tier)"
	)
	text = text.replace(
		"NORMAL TILING: one dark mass + straight borders + one edge joint reused for every rounded turn",
		"NORMAL TILING: dark mass + border + exposed Edge Joint + opposite Hole Corner"
	)
	return _write(WORKBENCH_PATH, text)

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = text.replace(
		"\tselected_inside_corner_textures = _build_authored_corner_textures(selected_convex_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_convex_image)",
		"\tselected_inside_corner_textures = _build_authored_corner_textures(selected_corner_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_corner_image)"
	)
	var old_pass := "\t# Empty-room corners reuse the same Edge Joint on the diagonal solid cell.\n\tfor y in range(MAP_SIZE.y):\n\t\tfor x in range(MAP_SIZE.x):\n\t\t\tvar solid_cell := Vector2i(x, y)\n\t\t\tif _is_solid(solid_cell):\n\t\t\t\t_draw_inside_corners(solid_cell, _cell_rect(solid_cell))"
	var new_pass := "\t# Opposite Hole Corners are replacement patches on diagonal solid cells.\n\tfor y in range(MAP_SIZE.y):\n\t\tfor x in range(MAP_SIZE.x):\n\t\t\tvar solid_cell := Vector2i(x, y)\n\t\t\tif _is_solid(solid_cell):\n\t\t\t\t_draw_hole_corners(solid_cell, _cell_rect(solid_cell))"
	text = _replace_required(text, old_pass, new_pass, "hole corner preview pass")
	if text.is_empty(): return false
	var start := text.find("func _draw_inside_corners(")
	var finish := text.find("func _cell_from_position", start)
	if start < 0 or finish < 0:
		push_error("Could not locate mixed corner preview block")
		return false
	var replacement := "func _draw_hole_corners(solid_cell: Vector2i, rect: Rect2) -> void:\n\t# Canonical source is a top-left cutout. Frames rotate clockwise. A hole\n\t# corner exists when the diagonal is empty but both cardinal neighbours stay solid.\n\tvar rules := [\n\t\t[Vector2i.UP, Vector2i.LEFT, Vector2i(-1, -1), 0],\n\t\t[Vector2i.UP, Vector2i.RIGHT, Vector2i(1, -1), 1],\n\t\t[Vector2i.DOWN, Vector2i.RIGHT, Vector2i(1, 1), 2],\n\t\t[Vector2i.DOWN, Vector2i.LEFT, Vector2i(-1, 1), 3],\n\t]\n\tfor rule_value in rules:\n\t\tvar rule: Array = rule_value\n\t\tvar first: Vector2i = rule[0]\n\t\tvar second: Vector2i = rule[1]\n\t\tvar diagonal: Vector2i = rule[2]\n\t\tvar frame: int = rule[3]\n\t\tif not _is_solid(solid_cell + first) or not _is_solid(solid_cell + second) or _is_solid(solid_cell + diagonal):\n\t\t\tcontinue\n\t\tvar textures := _inside_corner_textures_for(_cell_type(solid_cell))\n\t\tif frame >= textures.size() or textures[frame] == null:\n\t\t\tcontinue\n\t\tvar patch_size := rect.size.x * (14.0 / 32.0)\n\t\tvar patch_position := rect.position\n\t\tmatch frame:\n\t\t\t1: patch_position += Vector2(rect.size.x - patch_size, 0)\n\t\t\t2: patch_position += Vector2(rect.size.x - patch_size, rect.size.y - patch_size)\n\t\t\t3: patch_position += Vector2(0, rect.size.y - patch_size)\n\t\tdraw_rect(Rect2(patch_position, Vector2(patch_size, patch_size)), CAVE_COLOR)\n\t\tdraw_texture_rect(textures[frame], rect, false)\n\n"
	text = text.substr(0, start) + replacement + text.substr(finish)
	return _write(PREVIEW_PATH, text)
