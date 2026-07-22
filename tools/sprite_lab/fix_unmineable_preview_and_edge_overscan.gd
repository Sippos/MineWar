extends Node

const WORKBENCH := "res://tools/sprite_lab/dome_material_workbench.gd"
const PREVIEW := "res://tools/sprite_lab/dome_material_preview_v2.gd"
const WORLD := "res://scripts/systems/world_generation/world.gd"

func _replace_once(text: String, old_value: String, new_value: String, label: String) -> String:
	if not text.contains(old_value):
		push_error("Missing patch anchor: " + label)
		return text
	return text.replace(old_value, new_value)

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + path)
		return false
	file.store_string(text)
	file.close()
	return true

func _ready() -> void:
	var preview := FileAccess.get_file_as_string(PREVIEW)
	preview = _replace_once(
		preview,
		"var rounded_light_corners := true\nvar preview_brush: int = PreviewBrush.DIG",
		"var rounded_light_corners := true\n# The normal EASY cells in the demo cave act as the currently selected material.\n# This makes UNMINEABLE edge joints and Hole Corners immediately visible while\n# preserving the explicit medium/hard comparison blocks.\nvar primary_preview_tier := \"easy\"\nvar preview_brush: int = PreviewBrush.DIG",
		"preview primary tier variable"
	)
	preview = _replace_once(
		preview,
		"func set_preview_brush(value: int) -> void:\n\tpreview_brush = clampi(value, PreviewBrush.DIG, PreviewBrush.UNMINEABLE)\n",
		"func set_primary_preview_tier(tier: String) -> void:\n\tif not MATERIAL_TIERS.has(tier):\n\t\treturn\n\tprimary_preview_tier = tier\n\t_mark_extrusion_dirty()\n\nfunc set_preview_brush(value: int) -> void:\n\tpreview_brush = clampi(value, PreviewBrush.DIG, PreviewBrush.UNMINEABLE)\n",
		"preview primary tier setter"
	)
	preview = _replace_once(
		preview,
		"func _cell_type(cell: Vector2i) -> int:\n\tif cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:\n\t\treturn CellType.UNMINEABLE\n\treturn int(cells.get(cell, CellType.EASY))",
		"func _cell_type(cell: Vector2i) -> int:\n\tif cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:\n\t\treturn CellType.UNMINEABLE\n\tvar stored_type := int(cells.get(cell, CellType.EASY))\n\t# EASY is the preview's primary material slot. Selecting UNMINEABLE now\n\t# changes the large cave body as well, so its authored corners actually show.\n\tif stored_type == CellType.EASY:\n\t\treturn _cell_type_for_tier(primary_preview_tier)\n\treturn stored_type",
		"preview selected material mapping"
	)
	if not _write(PREVIEW, preview):
		get_tree().quit(1)
		return

	var workbench := FileAccess.get_file_as_string(WORKBENCH)
	workbench = _replace_once(
		workbench,
		"\tif current_mode == \"convex\":\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(EDGE_JOINT_SIZE, EDGE_JOINT_SIZE))",
		"\tif current_mode == \"convex\":\n\t\t# The 14x14 corner remains the destructive silhouette/cutout core, but the\n\t\t# whole tile is paintable overscan for highlights, chips and long curves.\n\t\treturn Rect2i(Vector2i.ZERO, Vector2i(LOGICAL_SIZE, LOGICAL_SIZE))",
		"edge joint full overscan region"
	)
	workbench = _replace_once(
		workbench,
		"\tif current_mode == \"convex\":\n\t\treturn \"%s EDGE JOINT • AUTHOR TOP-LEFT ONLY\" % current_tier.to_upper()",
		"\tif current_mode == \"convex\":\n\t\treturn \"%s EDGE JOINT • FULL 32x32 OVERSCAN\" % current_tier.to_upper()",
		"edge joint title"
	)
	workbench = _replace_once(
		workbench,
		"\tpreview.call(\"set_material_library\", mass_image, border_images, corner_images, convex_images, front_images)\n\ttitle_label.text = _workspace_title()",
		"\tpreview.call(\"set_material_library\", mass_image, border_images, corner_images, convex_images, front_images)\n\tpreview.call(\"set_primary_preview_tier\", visual_tier)\n\ttitle_label.text = _workspace_title()",
		"workbench selected preview tier"
	)
	workbench = _replace_once(
		workbench,
		"\telif current_mode == \"convex\":\n\t\tinstruction_label.text = \"Paint one TOP-LEFT EDGE JOINT for exposed solid corners. Hole Corner is now independent and will not change.\"",
		"\telif current_mode == \"convex\":\n\t\tinstruction_label.text = \"Paint the EDGE JOINT on the full 32x32 overscan tile. The original top-left 14x14 area remains the safe silhouette-cutout core; opaque details and curve continuation may extend across the rest of the tile.\"",
		"edge joint instruction"
	)
	if not _write(WORKBENCH, workbench):
		get_tree().quit(1)
		return

	var world := FileAccess.get_file_as_string(WORLD)
	world = _replace_once(
		world,
		"const INSIDE_CORNER_ATLAS_PATHS := {\n\t1: \"res://assets/sprites/world/terrain/dome/Easy_Inside_Corners.png\",\n\t2: \"res://assets/sprites/world/terrain/dome/Medium_Inside_Corners.png\",\n\t3: \"res://assets/sprites/world/terrain/dome/Hard_Inside_Corners.png\",\n}",
		"const INSIDE_CORNER_ATLAS_PATHS := {\n\t1: \"res://assets/sprites/world/terrain/dome/Easy_Inside_Corners.png\",\n\t2: \"res://assets/sprites/world/terrain/dome/Medium_Inside_Corners.png\",\n\t3: \"res://assets/sprites/world/terrain/dome/Hard_Inside_Corners.png\",\n\t16: \"res://assets/sprites/world/terrain/dome/Unmineable_Inside_Corners.png\",\n}",
		"runtime unmineable inside corner atlas"
	)
	if not _write(WORLD, world):
		get_tree().quit(1)
		return

	print("Unmineable preview updates, runtime Hole Corners, and 32x32 Edge Joint overscan applied.")
	get_tree().quit()
