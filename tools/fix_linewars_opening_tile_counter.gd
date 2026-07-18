extends Node

const TARGET_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(TARGET_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var replacements: Array[Dictionary] = [
		{
			"from": "var last_opening_route_length := 0\nvar opening_route_start_length := 1\n",
			"to": "var opening_topology_start := 0\nvar opening_dig_count := 0\n"
		},
		{
			"from": "\topening_route_start_length = _tunnel_route_length()\n\tlast_opening_route_length = opening_route_start_length\n\t_update_opening_route_marker(last_opening_route_length)\n",
			"to": "\topening_topology_start = _world_topology_revision()\n\topening_dig_count = 0\n\t_update_opening_route_marker(opening_dig_count)\n"
		},
		{
			"from": "\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tif opening_route != last_opening_route_length:\n\t\t\tlast_opening_route_length = opening_route\n\t\t\t_update_opening_route_marker(opening_route)\n\t\tif _opening_extension(opening_route) >= OPENING_REQUIRED_NEW_TILES:\n\t\t\t_complete_opening_build()\n\t\t_update_interface()\n\t\treturn\n",
			"to": "\tif opening_build_active:\n\t\tvar newly_dug_tiles := _opening_new_tiles_dug()\n\t\tif newly_dug_tiles != opening_dig_count:\n\t\t\topening_dig_count = newly_dug_tiles\n\t\t\t_update_opening_route_marker(opening_dig_count)\n\t\tif opening_dig_count >= OPENING_REQUIRED_NEW_TILES:\n\t\t\t_complete_opening_build()\n\t\t_update_interface()\n\t\treturn\n"
		},
		{
			"from": "func _update_opening_route_marker(route_length: int) -> void:\n\tvar marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif marker == null:\n\t\treturn\n\tmarker.global_position = _cell_world_position(_find_farthest_tunnel_cell())\n\tmarker.visible = opening_build_active\n\tvar caption := marker.get_node_or_null(\"Caption\") as Label\n\tif caption:\n\t\tcaption.text = \"SAFE ROUTE %d/%d\" % [mini(_opening_extension(route_length), OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n\nfunc _opening_extension(route_length: int) -> int:\n\treturn maxi(route_length - opening_route_start_length, 0)\n",
			"to": "func _update_opening_route_marker(newly_dug_tiles: int) -> void:\n\tvar marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif marker == null:\n\t\treturn\n\tmarker.global_position = _cell_world_position(_find_farthest_tunnel_cell())\n\tmarker.visible = opening_build_active\n\tvar caption := marker.get_node_or_null(\"Caption\") as Label\n\tif caption:\n\t\tcaption.text = \"SAFE ROUTE %d/%d\" % [mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n\nfunc _world_topology_revision() -> int:\n\tvar revision: Variant = world.get(\"topology_revision\") if world else null\n\treturn int(revision) if revision != null else 0\n\nfunc _opening_new_tiles_dug() -> int:\n\treturn maxi(_world_topology_revision() - opening_topology_start, 0)\n"
		},
		{
			"from": "\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tvar opening_extension := _opening_extension(opening_route)\n\t\tif opening_progress:\n\t\t\topening_progress.visible = true\n\t\t\topening_progress.max_value = OPENING_REQUIRED_NEW_TILES\n\t\t\topening_progress.value = mini(opening_extension, OPENING_REQUIRED_NEW_TILES)\n\t\tmode_label.text = \"OPENING PEON • BUILD SAFE ROUTE\"\n\t\tswitch_button.text = \"TUNNEL %d/%d\" % [mini(opening_extension, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n\t\tswitch_button.disabled = true\n\t\tradar_button.text = \"RADAR LOCKED\"\n\t\tradar_button.disabled = true\n\t\tthreat_label.text = \"WAVES PAUSED • DIG %d MORE\" % maxi(OPENING_REQUIRED_NEW_TILES - opening_extension, 0)\n",
			"to": "\tif opening_build_active:\n\t\tvar newly_dug_tiles := _opening_new_tiles_dug()\n\t\tif opening_progress:\n\t\t\topening_progress.visible = true\n\t\t\topening_progress.max_value = OPENING_REQUIRED_NEW_TILES\n\t\t\topening_progress.value = mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES)\n\t\tmode_label.text = \"OPENING PEON • BUILD SAFE ROUTE\"\n\t\tswitch_button.text = \"TUNNEL %d/%d\" % [mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n\t\tswitch_button.disabled = true\n\t\tradar_button.text = \"RADAR LOCKED\"\n\t\tradar_button.disabled = true\n\t\tthreat_label.text = \"WAVES PAUSED • DIG %d MORE\" % maxi(OPENING_REQUIRED_NEW_TILES - newly_dug_tiles, 0)\n"
		}
	]

	for replacement in replacements:
		var from_text := str(replacement["from"])
		var to_text := str(replacement["to"])
		var count := source.count(from_text)
		if count != 1:
			push_error("Expected one opening-counter match, found %d for: %s" % [count, from_text.left(90)])
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)

	var output := FileAccess.open(TARGET_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_OPENING_TILE_COUNTER_PASS")
	get_tree().quit(0)
