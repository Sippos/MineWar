extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const BUILDER_PATH := "res://tools/sprite_lab/dome_corner_builder.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const BACKUP_DIR := SOURCE_DIR + "/backups"
const LOGICAL_SIZE := 32
const CORNER_EDIT_SIZE := 14

func _replace_required(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing cave-corner patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _ready() -> void:
	var ok := _patch_builder() and _patch_workbench() and _create_clean_sources()
	print("Editable cave-corner workflow installed" if ok else "Cave-corner workflow patch failed")
	get_tree().quit(0 if ok else 1)

func _patch_builder() -> bool:
	var text := FileAccess.get_file_as_string(BUILDER_PATH)
	var marker := "static func make_inside_corner_top_left(top_border: Image) -> Image:"
	if not text.contains(marker):
		push_error("Could not find inside-corner builder")
		return false
	var start := text.find(marker)
	var finish := text.find("\nstatic func build_inside_corner_atlas", start)
	if finish < 0:
		push_error("Could not find end of inside-corner builder")
		return false
	var replacement := "static func make_cave_corner_top_left(mass_image: Image, top_border: Image) -> Image:\n\t# Empty-space corner: solid rock occupies the quarter disk near the cell\n\t# corner, while the bright border follows the OUTER arc and connects the\n\t# two neighbouring straight border strips.\n\tvar result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tresult.fill(Color.TRANSPARENT)\n\tvar depth := border_depth(top_border)\n\tvar radius := clampi(depth + 3, 7, CORNER_EDIT_SIZE - 1)\n\tfor y in range(radius + 1):\n\t\tfor x in range(radius + 1):\n\t\t\tvar distance := Vector2(float(x) + 0.5, float(y) + 0.5).length()\n\t\t\tif distance > float(radius):\n\t\t\t\tcontinue\n\t\t\tvar inward_depth := float(radius) - distance\n\t\t\tvar color: Color\n\t\t\tif inward_depth < float(depth):\n\t\t\t\tcolor = average_border_row(top_border, clampi(floori(inward_depth), 0, depth - 1))\n\t\t\telse:\n\t\t\t\tcolor = mass_image.get_pixel(clampi(x, 0, mass_image.get_width() - 1), clampi(y, 0, mass_image.get_height() - 1))\n\t\t\tif color.a > 0.05:\n\t\t\t\tresult.set_pixel(x, y, color)\n\tfor bridge in range(2):\n\t\tvar edge_color := average_border_row(top_border, bridge)\n\t\tresult.set_pixel(clampi(radius - bridge, 0, LOGICAL_SIZE - 1), 0, edge_color)\n\t\tresult.set_pixel(0, clampi(radius - bridge, 0, LOGICAL_SIZE - 1), edge_color)\n\treturn result\n\nstatic func make_inside_corner_top_left(top_border: Image) -> Image:\n\tvar fallback_mass := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\tfallback_mass.fill(Color.html(\"211e2dff\"))\n\treturn make_cave_corner_top_left(fallback_mass, top_border)\n"
	text = text.substr(0, start) + replacement + text.substr(finish)
	var file := FileAccess.open(BUILDER_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = text.replace(
		"_add_mode_button(controls, \"corner\", \"CONCAVE CORNER • one top-left connector\")",
		"_add_mode_button(controls, \"corner\", \"CAVE CORNER • empty-hole turn\")"
	)
	text = text.replace(
		"Each material has one straight border, one EDGE JOINT where two borders meet, and one inward CONCAVE connector. UNMINEABLE starts from the exact Easy artwork.",
		"Each material has a straight border, a solid-cell EDGE JOINT, and a CAVE CORNER inside empty space where two bright lines curve together."
	)
	var old_loader := "func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telif FileAccess.file_exists(runtime_path):\n\t\tvar atlas := Image.load_from_file(ProjectSettings.globalize_path(runtime_path))\n\t\tcorner = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)\n\t\tcorner.fill(Color.TRANSPARENT)\n\t\tcorner.blit_rect(atlas, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)\n\telse:\n\t\tcorner = CORNER_BUILDER.make_inside_corner_top_left(fallback_border)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner"
	var new_loader := "func _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\t# CAVE CORNER inside an empty cell, opposite the solid-cell edge joint.\n\tvar editable_path := SOURCE_DIR + \"/%s_cave_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telse:\n\t\tcorner = CORNER_BUILDER.make_cave_corner_top_left(mass_image, fallback_border)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner"
	text = _replace_required(text, old_loader, new_loader, "cave corner loader")
	if text.is_empty():
		return false
	text = text.replace(
		"return \"%s CONCAVE CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()",
		"return \"%s CAVE CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()"
	)
	text = text.replace(
		"instruction_label.text = \"Paint one TOP-LEFT inward concave connector. The game rotates it for the other three dirt-facing turns.\"",
		"instruction_label.text = \"Paint the TOP-LEFT corner INSIDE EMPTY CAVE SPACE. Its curved bright rim must connect the top and left straight borders; the game rotates it for the other three hole corners.\""
	)
	text = text.replace(
		"result = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_corner_top_left_32.png\" % tier)",
		"result = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_cave_corner_top_left_32.png\" % tier)"
	)
	text = text.replace(
		"Saved one mass, four borders, four edge joints and four concave connectors.",
		"Saved one mass, four borders, four edge joints and four editable cave corners."
	)
	text = text.replace(
		"Exported normal tiling: dark mass, borders, edge joints and concave connectors.",
		"Exported normal tiling: dark mass, borders, edge joints and cave-space corners."
	)
	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

func _create_clean_sources() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	var mass_path := SOURCE_DIR + "/dark_mass_32.png"
	if not FileAccess.file_exists(mass_path):
		push_error("Missing dark mass source")
		return false
	var mass: Image = Image.load_from_file(ProjectSettings.globalize_path(mass_path))
	mass.convert(Image.FORMAT_RGBA8)
	mass.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	for tier in ["easy", "medium", "hard"]:
		var old_path := SOURCE_DIR + "/%s_corner_top_left_32.png" % tier
		if FileAccess.file_exists(old_path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(old_path), ProjectSettings.globalize_path(BACKUP_DIR + "/%s_old_corner_%s.png" % [tier, stamp]))
		var border_path := SOURCE_DIR + "/%s_border_top_32.png" % tier
		if not FileAccess.file_exists(border_path):
			push_error("Missing border source for %s" % tier)
			return false
		var border: Image = Image.load_from_file(ProjectSettings.globalize_path(border_path))
		border.convert(Image.FORMAT_RGBA8)
		border.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
		var corner: Image = _make_clean_cave_corner(mass, border)
		if corner.save_png(SOURCE_DIR + "/%s_cave_corner_top_left_32.png" % tier) != OK:
			return false
	var easy_corner: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/easy_cave_corner_top_left_32.png"))
	return easy_corner.save_png(SOURCE_DIR + "/unmineable_cave_corner_top_left_32.png") == OK

func _border_depth(top_border: Image) -> int:
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
	return total / float(count) if count > 0 else Color.TRANSPARENT

func _make_clean_cave_corner(mass: Image, border: Image) -> Image:
	var result := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var depth := _border_depth(border)
	var radius := clampi(depth + 3, 7, CORNER_EDIT_SIZE - 1)
	for y in range(radius + 1):
		for x in range(radius + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).length()
			if distance > float(radius):
				continue
			var inward_depth := float(radius) - distance
			var color: Color
			if inward_depth < float(depth):
				color = _average_border_row(border, clampi(floori(inward_depth), 0, depth - 1))
			else:
				color = mass.get_pixel(clampi(x, 0, mass.get_width() - 1), clampi(y, 0, mass.get_height() - 1))
			if color.a > 0.05:
				result.set_pixel(x, y, color)
	for bridge in range(2):
		var edge_color := _average_border_row(border, bridge)
		result.set_pixel(clampi(radius - bridge, 0, LOGICAL_SIZE - 1), 0, edge_color)
		result.set_pixel(0, clampi(radius - bridge, 0, LOGICAL_SIZE - 1), edge_color)
	return result
