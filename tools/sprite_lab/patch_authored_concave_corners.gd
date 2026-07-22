extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW_PATH := "res://tools/sprite_lab/dome_material_preview.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const RUNTIME_DIR := "res://assets/sprites/world/terrain/dome"
const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")

func _ready() -> void:
	var ok := _patch_workbench() and _patch_preview() and _migrate_unmineable_and_corner_sources()
	print("Authored concave-corner workspaces installed" if ok else "Authored corner patch failed")
	get_tree().quit(0 if ok else 1)

func _replace_required(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func _patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)
	text = _replace_required(text,
		"var border_images: Dictionary = {}\nvar current_mode := \"border\"",
		"var border_images: Dictionary = {}\nvar corner_images: Dictionary = {}\nvar current_mode := \"border\"",
		"corner image state")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\t_add_mode_button(controls, \"border\", \"BORDER • one top stamp\")",
		"\t_add_mode_button(controls, \"border\", \"BORDER • one top stamp\")\n\t_add_mode_button(controls, \"corner\", \"CONCAVE CORNER • one top-left stamp\")",
		"corner mode button")
	if text.is_empty(): return false
	text = text.replace("2 • BORDER TYPE", "2 • MATERIAL TYPE")
	text = text.replace(
		"All four border types sit on the same dark mass. UNMINEABLE is only a gameplay/collision difference.",
		"Each material has one straight border and one authored concave corner. UNMINEABLE uses the same dark mass and differs only in gameplay/collision."
	)
	var old_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tborder_images[\"unmineable\"] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[\"unmineable\"]), FALLBACK_UNMINEABLE_PATH)\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))"
	var new_load := "func _load_images() -> void:\n\tmass_image = _load_png_or_svg_logical(RUNTIME_MASS_PATH, FALLBACK_MASS_PATH)\n\tborder_images.clear()\n\tcorner_images.clear()\n\tfor tier in [\"easy\", \"medium\", \"hard\"]:\n\t\tborder_images[tier] = _load_top_stamp(String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))\n\t# Unmineable deliberately begins with the exact Easy-rock appearance. It is\n\t# a gameplay property, not a different full block material.\n\tborder_images[\"unmineable\"] = (border_images[\"easy\"] as Image).duplicate()\n\tfor tier in TIERS:\n\t\tcorner_images[tier] = _load_corner_stamp(tier, String(RUNTIME_INSIDE_CORNER_PATHS[tier]), border_images[tier])"
	text = _replace_required(text, old_load, new_load, "image loading")
	if text.is_empty(): return false
	var insert_after := "\treturn stamp\n\nfunc _load_png_or_svg_logical"
	var corner_loader := "\treturn stamp\n\nfunc _load_corner_stamp(tier: String, runtime_path: String, fallback_border: Image) -> Image:\n\tvar editable_path := SOURCE_DIR + \"/%s_corner_top_left_32.png\" % tier\n\tvar corner: Image\n\tif FileAccess.file_exists(editable_path):\n\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))\n\telif FileAccess.file_exists(runtime_path):\n\t\tvar atlas := Image.load_from_file(ProjectSettings.globalize_path(runtime_path))\n\t\tcorner = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)\n\t\tcorner.fill(Color.TRANSPARENT)\n\t\tcorner.blit_rect(atlas, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i.ZERO)\n\telse:\n\t\tcorner = CORNER_BUILDER.make_inside_corner_top_left(fallback_border)\n\tcorner.convert(Image.FORMAT_RGBA8)\n\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)\n\treturn corner\n\nfunc _make_cave_base() -> Image:\n\tvar image := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)\n\timage.fill(Color.html(\"111725ff\"))\n\treturn image\n\nfunc _load_png_or_svg_logical"
	text = _replace_required(text, insert_after, corner_loader, "corner loader")
	if text.is_empty(): return false
	text = _replace_required(text,
		"func _active_image() -> Image:\n\treturn mass_image if current_mode == \"mass\" else border_images[current_tier]",
		"func _active_image() -> Image:\n\tif current_mode == \"mass\":\n\t\treturn mass_image\n\tif current_mode == \"corner\":\n\t\treturn corner_images[current_tier]\n\treturn border_images[current_tier]",
		"active image")
	if text.is_empty(): return false
	text = _replace_required(text,
		"func _active_region() -> Rect2i:\n\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE)) if current_mode == \"mass\" else Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))",
		"func _active_region() -> Rect2i:\n\tif current_mode == \"mass\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))\n\tif current_mode == \"corner\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(14, 14))\n\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, 11))",
		"active region")
	if text.is_empty(): return false
	text = _replace_required(text,
		"func _workspace_title() -> String:\n\treturn \"UNIVERSAL DARK MASS\" if current_mode == \"mass\" else \"%s BORDER • AUTHOR TOP ONLY\" % current_tier.to_upper()",
		"func _workspace_title() -> String:\n\tif current_mode == \"mass\":\n\t\treturn \"UNIVERSAL DARK MASS\"\n\tif current_mode == \"corner\":\n\t\treturn \"%s CONCAVE CORNER • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()\n\treturn \"%s BORDER • AUTHOR TOP ONLY\" % current_tier.to_upper()",
		"workspace title")
	if text.is_empty(): return false
	var old_refresh := "func _refresh_workspace() -> void:\n\tvar base: Image = mass_image if current_mode == \"border\" else null\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())\n\tvar inner_border: Image = border_images[\"easy\"] if current_tier == \"unmineable\" else border_images[current_tier]\n\tpreview.call(\"set_material_images\", mass_image, inner_border, border_images[\"unmineable\"])\n\ttitle_label.text = _workspace_title()\n\tinstruction_label.text = \"Paint the one dark full tile used under every rock type.\" if current_mode == \"mass\" else \"Paint only the CYAN TOP BAND. The game rotates it for four sides, convex joins and dirt-facing inside-corner connectors.\""
	var new_refresh := "func _refresh_workspace() -> void:\n\tvar base: Image = null\n\tif current_mode == \"border\":\n\t\tbase = mass_image\n\telif current_mode == \"corner\":\n\t\tbase = _make_cave_base()\n\tcanvas.call(\"set_workspace_images\", _active_image(), base, _active_region(), _workspace_title())\n\tvar inner_tier := \"easy\" if current_tier == \"unmineable\" else current_tier\n\tpreview.call(\"set_material_images\", mass_image, border_images[inner_tier], border_images[\"unmineable\"], corner_images[inner_tier], corner_images[\"unmineable\"])\n\ttitle_label.text = _workspace_title()\n\tif current_mode == \"mass\":\n\t\tinstruction_label.text = \"Paint the one dark full tile used under every rock type.\"\n\telif current_mode == \"corner\":\n\t\tinstruction_label.text = \"Paint one TOP-LEFT concave connector inside the cyan square. The game rotates it for the other three dirt-facing turns.\"\n\telse:\n\t\tinstruction_label.text = \"Paint only the CYAN TOP BAND. The game rotates it for all four straight edges and convex outer corners.\""
	text = _replace_required(text, old_refresh, new_refresh, "workspace refresh")
	if text.is_empty(): return false
	text = text.replace(
		"Locked area. Border artwork must stay inside the cyan top band.",
		"Locked area. Paint only inside the cyan authored region for this workspace."
	)
	text = _replace_required(text,
		"func _set_active_image(image: Image) -> void:\n\tif current_mode == \"mass\":\n\t\tmass_image = image\n\telse:\n\t\tborder_images[current_tier] = image",
		"func _set_active_image(image: Image) -> void:\n\tif current_mode == \"mass\":\n\t\tmass_image = image\n\telif current_mode == \"corner\":\n\t\tcorner_images[current_tier] = image\n\telse:\n\t\tborder_images[current_tier] = image",
		"set active image")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\tfor tier in TIERS:\n\t\tif result == OK:\n\t\t\tresult = (border_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_border_top_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass source and four border sources.\" if result == OK else \"Could not save sources: %s\" % error_string(result)",
		"\tfor tier in TIERS:\n\t\tif result == OK:\n\t\t\tresult = (border_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_border_top_32.png\" % tier)\n\t\tif result == OK:\n\t\t\tresult = (corner_images[tier] as Image).save_png(SOURCE_DIR + \"/%s_corner_top_left_32.png\" % tier)\n\tstatus_label.text = \"Saved one mass, four borders and four authored concave corners.\" if result == OK else \"Could not save sources: %s\" % error_string(result)",
		"save authored corners")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(border_images[tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))",
		"\t\tif result == OK:\n\t\t\tvar corner_atlas := _build_inside_corner_atlas(corner_images[tier])\n\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))",
		"export authored corner")
	if text.is_empty(): return false
	text = text.replace(
		"Exported four composite mass+border atlases with true rounded cutouts and four inside-corner atlases.",
		"Exported four composite border atlases plus four authored concave-corner atlases."
	)
	text = _replace_required(text,
		"func _build_inside_corner_atlas(top_border: Image) -> Image:\n\treturn CORNER_BUILDER.build_inside_corner_atlas(top_border)",
		"func _build_inside_corner_atlas(top_left_corner: Image) -> Image:\n\tvar atlas := Image.create(TILE_SIZE * 2, TILE_SIZE * 2, false, Image.FORMAT_RGBA8)\n\tatlas.fill(Color.TRANSPARENT)\n\tfor frame in range(4):\n\t\tvar corner := CORNER_BUILDER.rotate_quarters(top_left_corner, frame)\n\t\tcorner.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)\n\t\tatlas.blit_rect(corner, Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(frame % 2, frame / 2) * TILE_SIZE)\n\treturn atlas",
		"build authored corner atlas")
	if text.is_empty(): return false
	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		return false
	file.store_string(text)
	file.close()
	return true

func _patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW_PATH)
	text = _replace_required(text,
		"var unmineable_border_image: Image\nvar selected_composite_textures",
		"var unmineable_border_image: Image\nvar selected_corner_image: Image\nvar unmineable_corner_image: Image\nvar selected_composite_textures",
		"preview corner images")
	if text.is_empty(): return false
	text = _replace_required(text,
		"func set_material_images(new_mass_image: Image, selected_top_border: Image, unmineable_top_border: Image) -> void:\n\tmass_image = new_mass_image.duplicate()\n\tselected_border_image = selected_top_border.duplicate()\n\tunmineable_border_image = unmineable_top_border.duplicate()\n\t_rebuild_material_textures()",
		"func set_material_images(new_mass_image: Image, selected_top_border: Image, unmineable_top_border: Image, selected_top_left_corner: Image, unmineable_top_left_corner: Image) -> void:\n\tmass_image = new_mass_image.duplicate()\n\tselected_border_image = selected_top_border.duplicate()\n\tunmineable_border_image = unmineable_top_border.duplicate()\n\tselected_corner_image = selected_top_left_corner.duplicate()\n\tunmineable_corner_image = unmineable_top_left_corner.duplicate()\n\t_rebuild_material_textures()",
		"preview material signature")
	if text.is_empty(): return false
	text = _replace_required(text,
		"\tselected_inside_corner_textures = CORNER_BUILDER.build_inside_corner_textures(selected_border_image)\n\tunmineable_inside_corner_textures = CORNER_BUILDER.build_inside_corner_textures(unmineable_border_image)",
		"\tselected_inside_corner_textures = _build_authored_corner_textures(selected_corner_image)\n\tunmineable_inside_corner_textures = _build_authored_corner_textures(unmineable_corner_image)",
		"preview authored corner textures")
	if text.is_empty(): return false
	var before_square := "func _build_square_composite_textures(base: Image, top_border: Image) -> Array[ImageTexture]:"
	var helper := "func _build_authored_corner_textures(top_left_corner: Image) -> Array[ImageTexture]:\n\tvar result: Array[ImageTexture] = []\n\tfor turn in range(4):\n\t\tvar corner := CORNER_BUILDER.rotate_quarters(top_left_corner, turn)\n\t\tcorner.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)\n\t\tresult.append(ImageTexture.create_from_image(corner))\n\treturn result\n\nfunc _build_square_composite_textures(base: Image, top_border: Image) -> Array[ImageTexture]:"
	text = _replace_required(text, before_square, helper, "authored corner helper")
	if text.is_empty(): return false
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write preview")
		return false
	file.store_string(text)
	file.close()
	return true

func _migrate_unmineable_and_corner_sources() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_DIR))
	var easy_source_path := SOURCE_DIR + "/easy_border_top_32.png"
	var easy_border: Image
	if FileAccess.file_exists(easy_source_path):
		easy_border = Image.load_from_file(ProjectSettings.globalize_path(easy_source_path))
	else:
		var easy_atlas := Image.load_from_file(ProjectSettings.globalize_path(RUNTIME_DIR + "/Easy_Border_Atlas.png"))
		easy_border = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		easy_border.fill(Color.TRANSPARENT)
		easy_border.blit_rect(easy_atlas, Rect2i(Vector2i(64, 0), Vector2i(64, 64)), Vector2i.ZERO)
		easy_border.resize(32, 32, Image.INTERPOLATE_NEAREST)
	easy_border.convert(Image.FORMAT_RGBA8)
	if easy_border.save_png(SOURCE_DIR + "/unmineable_border_top_32.png") != OK:
		return false
	var easy_atlas_path := RUNTIME_DIR + "/Easy_Border_Atlas.png"
	if FileAccess.file_exists(easy_atlas_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(easy_atlas_path), ProjectSettings.globalize_path(RUNTIME_DIR + "/Unmineable_Border_Atlas.png"))
	for tier in ["easy", "medium", "hard"]:
		var atlas_path := RUNTIME_DIR + "/%s_Inside_Corners.png" % tier.capitalize()
		var corner: Image
		if FileAccess.file_exists(atlas_path):
			var atlas := Image.load_from_file(ProjectSettings.globalize_path(atlas_path))
			corner = Image.create(64, 64, false, Image.FORMAT_RGBA8)
			corner.fill(Color.TRANSPARENT)
			corner.blit_rect(atlas, Rect2i(Vector2i.ZERO, Vector2i(64, 64)), Vector2i.ZERO)
			corner.resize(32, 32, Image.INTERPOLATE_NEAREST)
		else:
			var border_path := SOURCE_DIR + "/%s_border_top_32.png" % tier
			var border := Image.load_from_file(ProjectSettings.globalize_path(border_path))
			corner = BUILDER.make_inside_corner_top_left(border)
		corner.save_png(SOURCE_DIR + "/%s_corner_top_left_32.png" % tier)
	var easy_corner := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/easy_corner_top_left_32.png"))
	easy_corner.save_png(SOURCE_DIR + "/unmineable_corner_top_left_32.png")
	var easy_corner_atlas := RUNTIME_DIR + "/Easy_Inside_Corners.png"
	if FileAccess.file_exists(easy_corner_atlas):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(easy_corner_atlas), ProjectSettings.globalize_path(RUNTIME_DIR + "/Unmineable_Inside_Corners.png"))
	return true
