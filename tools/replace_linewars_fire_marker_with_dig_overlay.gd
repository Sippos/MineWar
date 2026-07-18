extends Node

const TARGET_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(TARGET_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()

	source = _replace_once(source,
		"var world: Node2D\nvar block_layer: TileMapLayer\nvar hero: CharacterBody2D\n",
		"var world: Node2D\nvar block_layer: TileMapLayer\nvar opening_overlay_layer: TileMapLayer\nvar opening_front_overlay_layer: TileMapLayer\nvar opening_front_wall_layer: TileMapLayer\nvar hero: CharacterBody2D\n"
	)
	source = _replace_once(source,
		"var opening_topology_start := 0\nvar opening_dig_count := 0\nvar first_wave_warning_shown := false\n",
		"var opening_topology_start := 0\nvar opening_dig_count := 0\nvar opening_overlay_cells: Array[Vector2i] = []\nvar first_wave_warning_shown := false\n"
	)
	source = _replace_once(source,
		"\tif world:\n\t\tblock_layer = world.get_node_or_null(\"BlockLayer\") as TileMapLayer\n\t\thero = world.get_node_or_null(\"Player\") as CharacterBody2D\n",
		"\tif world:\n\t\tblock_layer = world.get_node_or_null(\"BlockLayer\") as TileMapLayer\n\t\topening_overlay_layer = world.get_node_or_null(\"DamageLayer\") as TileMapLayer\n\t\topening_front_overlay_layer = world.get_node_or_null(\"FrontDamageLayer\") as TileMapLayer\n\t\topening_front_wall_layer = world.get_node_or_null(\"FrontWallLayer\") as TileMapLayer\n\t\thero = world.get_node_or_null(\"Player\") as CharacterBody2D\n"
	)
	source = _replace_once(source,
		"\tif world == null or block_layer == null or hero == null or base == null:\n",
		"\tif world == null or block_layer == null or opening_overlay_layer == null or hero == null or base == null:\n"
	)
	source = _replace_once(source,
		"\tcommand_message = \"Build the opening tunnel: dig 5 new tiles in any shape. Waves stay paused until the route is safe.\"\n",
		"\tcommand_message = \"Dig the marked dirt blocks to shape the opening tunnel. The overlay follows the peon; waves stay paused until 5/5.\"\n"
	)
	source = _replace_once(source,
		"\tif opening_build_active:\n\t\tvar newly_dug_tiles := _opening_new_tiles_dug()\n\t\tif newly_dug_tiles != opening_dig_count:\n\t\t\topening_dig_count = newly_dug_tiles\n\t\t\t_update_opening_route_marker(opening_dig_count)\n\t\tif opening_dig_count >= OPENING_REQUIRED_NEW_TILES:\n",
		"\tif opening_build_active:\n\t\tvar newly_dug_tiles := _opening_new_tiles_dug()\n\t\tif newly_dug_tiles != opening_dig_count:\n\t\t\topening_dig_count = newly_dug_tiles\n\t\t_update_opening_route_marker(opening_dig_count)\n\t\tif opening_dig_count >= OPENING_REQUIRED_NEW_TILES:\n"
	)
	source = _replace_once(source,
		"\tvar opening_marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif opening_marker:\n\t\topening_marker.visible = false\n",
		"\t_clear_opening_dig_overlays()\n"
	)
	source = _replace_once(source,
		"\t\tcommand_message = \"Tile carved. Tap beside the peon again, or use movement controls, until the safe route reaches 5/5.\"\n",
		"\t\tcommand_message = \"Tile carved. Dig another marked block until the safe route reaches 5/5.\"\n"
	)
	source = _replace_once(source,
		"func _build_portal_markers() -> void:\n\tportal_nodes[\"OpeningRouteEnd\"] = _create_world_marker(\"OpeningRouteEnd\", tunnel_exit_cell, Color(1.0, 0.78, 0.2, 0.96), \"SAFE ROUTE 0/5\", 14.0)\n\tvar opening_caption := (portal_nodes[\"OpeningRouteEnd\"] as Node2D).get_node_or_null(\"Caption\") as Label\n\tif opening_caption:\n\t\topening_caption.position = Vector2(-58, -48)\n\t\topening_caption.size = Vector2(116, 24)\n\t\topening_caption.add_theme_font_size_override(\"font_size\", 12)\n",
		"func _build_portal_markers() -> void:\n"
	)
	source = _replace_once(source,
		"func _update_opening_route_marker(newly_dug_tiles: int) -> void:\n\tvar marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif marker == null:\n\t\treturn\n\tmarker.global_position = _cell_world_position(_find_farthest_tunnel_cell())\n\tmarker.visible = opening_build_active\n\tvar caption := marker.get_node_or_null(\"Caption\") as Label\n\tif caption:\n\t\tcaption.text = \"SAFE ROUTE %d/%d\" % [mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n",
		"func _update_opening_route_marker(_newly_dug_tiles: int) -> void:\n\tif opening_overlay_layer == null:\n\t\treturn\n\tvar active_dig_cell := INVALID_CELL\n\tif peon:\n\t\tvar raw_dig_cell: Variant = peon.get(\"current_dig_cell\")\n\t\tif raw_dig_cell is Vector2i:\n\t\t\tactive_dig_cell = raw_dig_cell\n\n\tvar next_overlay_cells: Array[Vector2i] = []\n\tif opening_build_active and peon:\n\t\tvar peon_cell := block_layer.local_to_map(block_layer.to_local(peon.global_position))\n\t\tfor direction_value in CARDINAL_DIRECTIONS:\n\t\t\tvar direction: Vector2i = direction_value\n\t\t\tvar candidate := peon_cell + direction\n\t\t\tif _is_surface_cell(candidate) and block_layer.get_cell_source_id(candidate) != -1:\n\t\t\t\tnext_overlay_cells.append(candidate)\n\n\tfor old_cell in opening_overlay_cells:\n\t\tif old_cell == active_dig_cell:\n\t\t\tcontinue\n\t\tif not next_overlay_cells.has(old_cell):\n\t\t\topening_overlay_layer.erase_cell(old_cell)\n\t\t\tif opening_front_overlay_layer:\n\t\t\t\topening_front_overlay_layer.erase_cell(old_cell + Vector2i.DOWN)\n\n\topening_overlay_cells = next_overlay_cells\n\tfor overlay_cell in opening_overlay_cells:\n\t\tif overlay_cell == active_dig_cell:\n\t\t\tcontinue\n\t\topening_overlay_layer.set_cell(overlay_cell, 7, Vector2i.ZERO)\n\t\tif opening_front_overlay_layer and opening_front_wall_layer:\n\t\t\tvar below_cell := overlay_cell + Vector2i.DOWN\n\t\t\tif opening_front_wall_layer.get_cell_source_id(below_cell) != -1:\n\t\t\t\topening_front_overlay_layer.set_cell(below_cell, 13, Vector2i.ZERO)\n\t\t\telse:\n\t\t\t\topening_front_overlay_layer.erase_cell(below_cell)\n\nfunc _clear_opening_dig_overlays() -> void:\n\tif opening_overlay_layer:\n\t\tfor overlay_cell in opening_overlay_cells:\n\t\t\topening_overlay_layer.erase_cell(overlay_cell)\n\t\t\tif opening_front_overlay_layer:\n\t\t\t\topening_front_overlay_layer.erase_cell(overlay_cell + Vector2i.DOWN)\n\topening_overlay_cells.clear()\n"
	)

	if source.is_empty():
		get_tree().quit(1)
		return
	var output := FileAccess.open(TARGET_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_OPENING_DIG_OVERLAY_PASS")
	get_tree().quit(0)

func _replace_once(source: String, from_text: String, to_text: String) -> String:
	var count := source.count(from_text)
	if count != 1:
		push_error("Expected one replacement, found %d for: %s" % [count, from_text.left(72)])
		return ""
	return source.replace(from_text, to_text)
