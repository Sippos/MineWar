extends Node

const WORKBENCH_PATH := "res://tools/sprite_lab/dome_material_workbench.gd"

func _replace_required(text: String, old: String, new: String, label: String) -> String:
	if not text.contains(old):
		push_error("Could not find patch section: %s" % label)
		get_tree().quit(1)
		return text
	return text.replace(old, new)

func _ready() -> void:
	var text := FileAccess.get_file_as_string(WORKBENCH_PATH)

	var old_load := '''	for tier in ["easy", "medium", "hard"]:
		border_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))
		convex_images[tier] = _load_convex_stamp(tier, border_images[tier])
	_sync_derived_hole_corners()

func _sync_derived_hole_corners() -> void:
	# Hole Corner has no independent artwork. It is always the exact inverse of
	# Edge Joint, so geometry, palette and edits can never drift apart.
	for tier in ["easy", "medium", "hard"]:
		corner_images[tier] = CORNER_BUILDER.make_hole_corner_top_left(
			mass_image,
			border_images[tier],
			convex_images[tier]
		)
	border_images["unmineable"] = (border_images["easy"] as Image).duplicate()
	convex_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
	corner_images["unmineable"] = (corner_images["easy"] as Image).duplicate()
'''
	var new_load := '''	for tier in ["easy", "medium", "hard"]:
		border_images[tier] = _load_editable_border_stamp(tier, String(RUNTIME_BORDER_PATHS[tier]), String(FALLBACK_EDGE_PATHS[tier]))
		convex_images[tier] = _load_convex_stamp(tier, border_images[tier])
		corner_images[tier] = _load_hole_corner_stamp(tier, convex_images[tier])
	# Unmineable mirrors Easy visually but remains mechanically unbreakable.
	border_images["unmineable"] = (border_images["easy"] as Image).duplicate()
	convex_images["unmineable"] = (convex_images["easy"] as Image).duplicate()
	corner_images["unmineable"] = (corner_images["easy"] as Image).duplicate()
'''
	text = _replace_required(text, old_load, new_load, "load editable Hole Corners")

	text = _replace_required(
		text,
		'_add_mode_button(controls, "corner", "HOLE CORNER • derived inverse of Edge Joint")',
		'_add_mode_button(controls, "corner", "HOLE CORNER • editable opposite turn")',
		"Hole Corner button label"
	)
	text = _replace_required(
		text,
		'\t\treturn "%s HOLE CORNER • EXACT INVERSE OF EDGE JOINT" % current_tier.to_upper()',
		'\t\treturn "%s HOLE CORNER • EDIT TOP-LEFT ONLY" % current_tier.to_upper()',
		"Hole Corner workspace title"
	)
	text = _replace_required(text, "func _refresh_workspace() -> void:\n\t_sync_derived_hole_corners()", "func _refresh_workspace() -> void:", "remove refresh regeneration")
	text = _replace_required(text, '\tcanvas.call("set_read_only", current_mode == "corner")', '\tcanvas.call("set_read_only", false)', "make canvas editable")
	text = _replace_required(
		text,
		'\t\tinstruction_label.text = "DERIVED PREVIEW: this is the exact solid/cave inverse of Edge Joint. Edit EDGE JOINT; Hole Corner updates automatically and rotates four ways."',
		'\t\tinstruction_label.text = "Paint the TOP-LEFT HOLE CORNER directly, exactly like Edge Joint. It started as the opposite/inverted turn and rotates automatically into all four directions."',
		"editable instruction"
	)
	text = _replace_required(
		text,
		'''func _stroke_started(cell: Vector2i, mouse_button: int) -> void:
	if current_mode == "corner":
		status_label.text = "Hole Corner is derived. Edit EDGE JOINT to change both matching curves."
		return
''',
		'''func _stroke_started(cell: Vector2i, mouse_button: int) -> void:
''',
		"enable corner strokes"
	)
	text = _replace_required(
		text,
		'''func _apply_brush(cell: Vector2i, mouse_button: int) -> void:
	if current_mode == "corner":
		return
''',
		'''func _apply_brush(cell: Vector2i, mouse_button: int) -> void:
''',
		"enable corner brush"
	)
	text = _replace_required(
		text,
		'''\tif current_mode == "corner":
		return
	elif current_mode == "convex":''',
		'''\tif current_mode == "corner":
		corner_images[tier] = image
	elif current_mode == "convex":''',
		"restore corner undo/redo"
	)
	text = _replace_required(text, "func _save_sources() -> void:\n\t_sync_derived_hole_corners()", "func _save_sources() -> void:", "remove save regeneration")
	text = _replace_required(text, "func _export_runtime_assets() -> void:\n\t_sync_derived_hole_corners()", "func _export_runtime_assets() -> void:", "remove export regeneration")
	text = _replace_required(
		text,
		'"Saved one mass, four borders, four edge joints and four derived inverse hole corners."',
		'"Saved one mass, four borders, four edge joints and four editable hole corners."',
		"save status"
	)

	var file := FileAccess.open(WORKBENCH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write workbench")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("Hole Corner restored as a normal editable sprite like Edge Joint")
	get_tree().quit()
