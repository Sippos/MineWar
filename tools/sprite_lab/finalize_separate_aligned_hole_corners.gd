extends Node

const WORKBENCH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW := "res://tools/sprite_lab/dome_material_preview.gd"
const WORLD := "res://scripts/systems/world_generation/world.gd"
const SOURCE_DIR := "res://tools/sprite_lab/source/dome_material"
const BUILDER := preload("res://tools/sprite_lab/dome_corner_builder.gd")
const N := 32
const TIERS: Array[String] = ["easy", "medium", "hard"]

func replace_once(text: String, old: String, replacement: String, label: String) -> String:
	if not text.contains(old):
		push_error("Missing patch target: %s" % label)
		return ""
	return text.replace(old, replacement)

func write_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true

func patch_workbench() -> bool:
	var text := FileAccess.get_file_as_string(WORKBENCH)

	text = replace_once(text,
		'''\t\t# Hole Corner and Edge Joint are the same authored 14x14 source.
\t\tcorner_images[tier] = convex_images[tier]''',
		'''\t\t# Hole Corner starts from the same curve but remains independently editable.
\t\tcorner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])''',
		"separate image loading")
	if text.is_empty(): return false

	text = replace_once(text,
		'''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
\t# Compatibility helper: Hole Corner literally shares the Edge Joint source.
\treturn edge_joint
''',
		'''func _load_hole_corner_stamp(tier: String, edge_joint: Image) -> Image:
\tvar editable_path := SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier
\tvar corner: Image
\tif FileAccess.file_exists(editable_path):
\t\tcorner = Image.load_from_file(ProjectSettings.globalize_path(editable_path))
\telse:
\t\tcorner = CORNER_BUILDER.make_hole_corner_top_left(mass_image, border_images[tier], edge_joint)
\tcorner.convert(Image.FORMAT_RGBA8)
\tcorner.resize(LOGICAL_SIZE, LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
\tvar clean := Image.create(LOGICAL_SIZE, LOGICAL_SIZE, false, Image.FORMAT_RGBA8)
\tclean.fill(Color.TRANSPARENT)
\tfor y in range(CORNER_PATCH_SIZE):
\t\tfor x in range(CORNER_PATCH_SIZE):
\t\t\tclean.set_pixel(x, y, corner.get_pixel(x, y))
\treturn clean
''',
		"independent Hole Corner loader")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\tif current_mode == "corner":
\t\treturn convex_images[tier]
\tif current_mode == "convex":''',
		'''\tif current_mode == "corner":
\t\treturn corner_images[tier]
\tif current_mode == "convex":''',
		"active Hole Corner image")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\tif current_mode == "corner":
\t\treturn "%s HOLE CORNER • SHARED EDGE JOINT" % current_tier.to_upper()''',
		'''\tif current_mode == "corner":
\t\treturn "%s HOLE CORNER • EDIT TOP-LEFT ONLY" % current_tier.to_upper()''',
		"Hole Corner title")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\telif current_mode == "corner":
\t\tbase = _make_convex_base(visual_tier)''',
		'''\telif current_mode == "corner":
\t\tbase = _make_cave_base()''',
		"Hole Corner canvas base")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\telif current_mode == "corner":
\t\tinstruction_label.text = "Hole Corner uses the exact same 14x14 sprite as Edge Joint. Edit either workspace; preview and export rotate this shared patch into all four hole corners."''',
		'''\telif current_mode == "corner":
\t\tinstruction_label.text = "Hole Corner uses the same 14x14 curve and endpoint coordinates as Edge Joint, but swaps the solid and cave sides. It is independently editable and rotates automatically four ways."''',
		"Hole Corner instructions")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\tif current_mode == "corner":
\t\tconvex_images[tier] = image
\t\tcorner_images[tier] = image
\telif current_mode == "convex":''',
		'''\tif current_mode == "corner":
\t\tcorner_images[tier] = image
\telif current_mode == "convex":''',
		"independent set active image")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\t\tif result == OK:
\t\t\tresult = (convex_images[source_tier] as Image).save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
\tstatus_label.text = "Saved one mass, four borders, and four shared Edge Joint/Hole Corner sources." if result == OK else "Could not save sources: %s" % error_string(result)''',
		'''\t\tif result == OK:
\t\t\tresult = (corner_images[source_tier] as Image).save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
\tstatus_label.text = "Saved one mass, four borders, four edge joints and four independent hole corners." if result == OK else "Could not save sources: %s" % error_string(result)''',
		"save independent Hole Corner")
	if text.is_empty(): return false

	text = replace_once(text,
		'''\t\tif result == OK:
\t\t\tvar corner_atlas := _build_inside_corner_atlas(convex_images[source_tier])
\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))
\t_save_sources()
\tstatus_label.text = "Exported four border atlases plus four Hole Corner atlases from the shared Edge Joint source." if result == OK else "Runtime export failed: %s" % error_string(result)''',
		'''\t\tif result == OK:
\t\t\tvar corner_atlas := _build_inside_corner_atlas(corner_images[source_tier])
\t\t\tresult = corner_atlas.save_png(String(RUNTIME_INSIDE_CORNER_PATHS[tier]))
\t_save_sources()
\tstatus_label.text = "Exported four border atlases plus four independently editable Hole Corner atlases." if result == OK else "Runtime export failed: %s" % error_string(result)''',
		"export independent Hole Corner")
	if text.is_empty(): return false

	text = text.replace(
		"Each material has one straight BORDER and one 14x14 EDGE JOINT source. HOLE CORNER reuses that exact sprite at the same native size and rotates it automatically four ways.",
		"Each material has one straight BORDER, one 14x14 EDGE JOINT, and one independent 14x14 HOLE CORNER. Both corner sprites share the same curve coordinates but have opposite solid/cave sides."
	)

	return write_file(WORKBENCH, text)

func patch_preview() -> bool:
	var text := FileAccess.get_file_as_string(PREVIEW)
	var old := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
\t# Native 14x14 patch placed directly in the matching corner of the empty cell.
\tvar patch_position := rect.position
\tmatch frame:
\t\t1: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.position.y)
\t\t2: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE, rect.end.y - CORNER_PATCH_SIZE)
\t\t3: patch_position = Vector2(rect.position.x, rect.end.y - CORNER_PATCH_SIZE)
\treturn Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''
	var replacement := '''func _hole_corner_patch_rect(rect: Rect2, frame: int) -> Rect2:
\t# Overlap the neighbouring straight-border endpoints by one logical pixel.
\t# This keeps the 14x14 curve at native scale while closing the visible seam.
\tvar patch_position := rect.position - Vector2.ONE
\tmatch frame:
\t\t1: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.position.y - 1.0)
\t\t2: patch_position = Vector2(rect.end.x - CORNER_PATCH_SIZE + 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)
\t\t3: patch_position = Vector2(rect.position.x - 1.0, rect.end.y - CORNER_PATCH_SIZE + 1.0)
\treturn Rect2(patch_position, Vector2(CORNER_PATCH_SIZE, CORNER_PATCH_SIZE))
'''
	text = replace_once(text, old, replacement, "preview one-pixel overlap")
	if text.is_empty(): return false
	return write_file(PREVIEW, text)

func patch_world() -> bool:
	var text := FileAccess.get_file_as_string(WORLD)
	var old := '''\t\t# Atlas frames are normal 64x64 empty-cell overlays containing one native
\t\t# 14x14 shared Edge Joint patch in the appropriate corner.
\t\tsprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell)))
'''
	var replacement := '''\t\t# The atlas frame is centered on the empty cell, then shifted two rendered
\t\t# pixels outward so its native 14x14 patch overlaps both straight endpoints.
\t\tvar corner_offset := Vector2(-2.0, -2.0)
\t\tmatch frame:
\t\t\t1: corner_offset = Vector2(2.0, -2.0)
\t\t\t2: corner_offset = Vector2(2.0, 2.0)
\t\t\t3: corner_offset = Vector2(-2.0, 2.0)
\t\tsprite.position = inside_corner_layer.to_local(block_layer.to_global(block_layer.map_to_local(cell))) + corner_offset
'''
	text = replace_once(text, old, replacement, "runtime one-pixel logical overlap")
	if text.is_empty(): return false
	return write_file(WORLD, text)

func load_source(name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + "/" + name))
	if image == null or image.is_empty():
		push_error("Could not load %s" % name)
		return Image.new()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(N, N, Image.INTERPOLATE_NEAREST)
	return image

func regenerate_sources() -> bool:
	var mass := load_source("dark_mass_32.png")
	if mass.is_empty(): return false
	for tier in TIERS:
		var border := load_source("%s_border_top_32.png" % tier)
		var joint := load_source("%s_edge_joint_top_left_32.png" % tier)
		if border.is_empty() or joint.is_empty(): return false
		var hole := BUILDER.make_hole_corner_top_left(mass, border, joint)
		var result := hole.save_png(SOURCE_DIR + "/%s_hole_corner_top_left_32.png" % tier)
		if result != OK:
			push_error("Could not save %s Hole Corner" % tier)
			return false
	# Unmineable mirrors Easy visually.
	var easy := load_source("easy_hole_corner_top_left_32.png")
	if easy.is_empty(): return false
	return easy.save_png(SOURCE_DIR + "/unmineable_hole_corner_top_left_32.png") == OK

func verify_independent_sources() -> bool:
	for tier in TIERS:
		var joint := load_source("%s_edge_joint_top_left_32.png" % tier)
		var hole := load_source("%s_hole_corner_top_left_32.png" % tier)
		if joint.is_empty() or hole.is_empty(): return false
		if joint == hole:
			push_error("%s Hole Corner still equals Edge Joint image object/data" % tier)
			return false
		# Both must stay confined to the same native 14x14 coordinates.
		for y in range(N):
			for x in range(N):
				if (x >= 14 or y >= 14) and hole.get_pixel(x, y).a > 0.05:
					push_error("%s Hole Corner has pixels outside 14x14 at %s" % [tier, Vector2i(x,y)])
					return false
	return true

func _ready() -> void:
	if not patch_workbench() or not patch_preview() or not patch_world() or not regenerate_sources() or not verify_independent_sources():
		get_tree().quit(1)
		return
	print("Hole Corners separated, inverted, aligned, and verified")
	get_tree().quit()
