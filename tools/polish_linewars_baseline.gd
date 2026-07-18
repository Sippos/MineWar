extends Node

const CONTROLLER_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(CONTROLLER_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var replacements: Array[Dictionary] = [
		{
			"from": "const MINIMUM_OPENING_ROUTE_LENGTH := 6\nconst INVASION_INTERVAL := 24.0\n",
			"to": "const MINIMUM_OPENING_ROUTE_LENGTH := 6\nconst OPENING_REQUIRED_NEW_TILES := MINIMUM_OPENING_ROUTE_LENGTH - 1\nconst INVASION_INTERVAL := 24.0\n"
		},
		{
			"from": "var alert_timer := 0.0\nvar last_opening_route_length := 0\n",
			"to": "var alert_timer := 0.0\nvar last_opening_route_length := 0\nvar opening_route_start_length := 1\n"
		},
		{
			"from": "\tlast_opening_route_length = _tunnel_route_length()\n\t_update_opening_route_marker(last_opening_route_length)\n\t_apply_control()\n\tcommand_message = \"Opening build: directly control the peon and dig upward until the safe-route meter is full. Waves are paused.\"\n",
			"to": "\topening_route_start_length = _tunnel_route_length()\n\tlast_opening_route_length = opening_route_start_length\n\t_update_opening_route_marker(last_opening_route_length)\n\t_apply_control()\n\tcommand_message = \"Build the opening tunnel: dig 5 new tiles in any shape. Waves stay paused until the route is safe.\"\n"
		},
		{
			"from": "\t\tif opening_route >= MINIMUM_OPENING_ROUTE_LENGTH:\n\t\t\t_complete_opening_build()\n",
			"to": "\t\tif _opening_extension(opening_route) >= OPENING_REQUIRED_NEW_TILES:\n\t\t\t_complete_opening_build()\n"
		},
		{
			"from": "\tcommand_message = \"Safe route established. Hero control restored; first invasion begins after the warning clock.\"\n",
			"to": "\tcommand_message = \"Hero active. Mine below; Tab / RB opens peon orders. First invasion in 28 seconds.\"\n"
		},
		{
			"from": "\t_show_alert(\"SAFE ROUTE ESTABLISHED\\nHERO CONTROL RESTORED\", 2.0)\n",
			"to": "\t_show_alert(\"SAFE ROUTE ESTABLISHED\\nHERO CONTROL RESTORED\", 2.2)\n"
		},
		{
			"from": "func _build_portal_markers() -> void:\n\tportal_nodes[\"OpeningRouteEnd\"] = _create_world_marker(\"OpeningRouteEnd\", tunnel_exit_cell, Color(1.0, 0.78, 0.2, 0.96), \"ROUTE END 1/6\", 20.0)\n",
			"to": "func _build_portal_markers() -> void:\n\tportal_nodes[\"OpeningRouteEnd\"] = _create_world_marker(\"OpeningRouteEnd\", tunnel_exit_cell, Color(1.0, 0.78, 0.2, 0.96), \"SAFE ROUTE 0/5\", 14.0)\n\tvar opening_caption := (portal_nodes[\"OpeningRouteEnd\"] as Node2D).get_node_or_null(\"Caption\") as Label\n\tif opening_caption:\n\t\topening_caption.position = Vector2(-58, -48)\n\t\topening_caption.size = Vector2(116, 24)\n\t\topening_caption.add_theme_font_size_override(\"font_size\", 12)\n"
		},
		{
			"from": "func _update_opening_route_marker(route_length: int) -> void:\n\tvar marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif marker == null:\n\t\treturn\n\tmarker.global_position = _cell_world_position(_find_farthest_tunnel_cell())\n\tmarker.visible = opening_build_active\n\tvar caption := marker.get_node_or_null(\"Caption\") as Label\n\tif caption:\n\t\tcaption.text = \"ROUTE END %d/%d\" % [mini(route_length, MINIMUM_OPENING_ROUTE_LENGTH), MINIMUM_OPENING_ROUTE_LENGTH]\n",
			"to": "func _update_opening_route_marker(route_length: int) -> void:\n\tvar marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif marker == null:\n\t\treturn\n\tmarker.global_position = _cell_world_position(_find_farthest_tunnel_cell())\n\tmarker.visible = opening_build_active\n\tvar caption := marker.get_node_or_null(\"Caption\") as Label\n\tif caption:\n\t\tcaption.text = \"SAFE ROUTE %d/%d\" % [mini(_opening_extension(route_length), OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n\nfunc _opening_extension(route_length: int) -> int:\n\treturn maxi(route_length - opening_route_start_length, 0)\n"
		},
		{
			"from": "\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tif opening_progress:\n\t\t\topening_progress.visible = true\n\t\t\topening_progress.max_value = MINIMUM_OPENING_ROUTE_LENGTH\n\t\t\topening_progress.value = mini(opening_route, MINIMUM_OPENING_ROUTE_LENGTH)\n\t\tmode_label.text = \"OPENING PEON • DIG SAFE ROUTE\"\n\t\tswitch_button.text = \"ROUTE %d/%d\" % [mini(opening_route, MINIMUM_OPENING_ROUTE_LENGTH), MINIMUM_OPENING_ROUTE_LENGTH]\n\t\tswitch_button.disabled = true\n\t\tradar_button.text = \"RADAR LOCKED • FINISH ROUTE\"\n\t\tradar_button.disabled = true\n\t\tthreat_label.text = \"WAVES PAUSED • DIG %d MORE\" % maxi(MINIMUM_OPENING_ROUTE_LENGTH - opening_route, 0)\n",
			"to": "\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tvar opening_extension := _opening_extension(opening_route)\n\t\tif opening_progress:\n\t\t\topening_progress.visible = true\n\t\t\topening_progress.max_value = OPENING_REQUIRED_NEW_TILES\n\t\t\topening_progress.value = mini(opening_extension, OPENING_REQUIRED_NEW_TILES)\n\t\tmode_label.text = \"OPENING PEON • BUILD SAFE ROUTE\"\n\t\tswitch_button.text = \"TUNNEL %d/%d\" % [mini(opening_extension, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]\n\t\tswitch_button.disabled = true\n\t\tradar_button.text = \"RADAR LOCKED\"\n\t\tradar_button.disabled = true\n\t\tthreat_label.text = \"WAVES PAUSED • DIG %d MORE\" % maxi(OPENING_REQUIRED_NEW_TILES - opening_extension, 0)\n"
		}
	]
	for replacement in replacements:
		var from_text := str(replacement["from"])
		var to_text := str(replacement["to"])
		var count := source.count(from_text)
		if count != 1:
			push_error("Expected one LineWars polish match, found %d for %s" % [count, from_text.left(80)])
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)
	var output := FileAccess.open(CONTROLLER_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_BASELINE_POLISH_PASS")
	get_tree().quit(0)
