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
			"from": "var switch_button: Button\nvar radar_button: Button\n",
			"to": "var switch_button: Button\nvar radar_button: Button\nvar opening_progress: ProgressBar\nvar alert_banner: PanelContainer\nvar alert_label: Label\n"
		},
		{
			"from": "var last_spawn_cell := Vector2i.ZERO\nvar current_telegraph_duration := TELEGRAPH_DURATION\n",
			"to": "var last_spawn_cell := Vector2i.ZERO\nvar current_telegraph_duration := TELEGRAPH_DURATION\nvar alert_timer := 0.0\nvar last_opening_route_length := 0\n"
		},
		{
			"from": "\t_build_portal_markers()\n\t_build_hud()\n\t_apply_control()\n",
			"to": "\t_build_portal_markers()\n\t_build_hud()\n\tlast_opening_route_length = _tunnel_route_length()\n\t_update_opening_route_marker(last_opening_route_length)\n\t_apply_control()\n"
		},
		{
			"from": "\tradar_button = hud.get_node(\"TopBar/Margin/Row/Radar\") as Button\n\tthreat_label = hud.get_node(\"TopBar/Margin/Row/Threat\") as Label\n\thint_label = hud.get_node(\"HintPanel/Margin/Hint\") as Label\n",
			"to": "\tradar_button = hud.get_node(\"TopBar/Margin/Row/Radar\") as Button\n\tthreat_label = hud.get_node(\"TopBar/Margin/Row/Threat\") as Label\n\thint_label = hud.get_node(\"HintPanel/Margin/Hint\") as Label\n\topening_progress = hud.get_node(\"OpeningProgress\") as ProgressBar\n\talert_banner = hud.get_node(\"AlertBanner\") as PanelContainer\n\talert_label = hud.get_node(\"AlertBanner/Margin/Alert\") as Label\n"
		},
		{
			"from": "func _process(delta: float) -> void:\n\tif Input.is_action_just_pressed(\"switch_front\"):\n",
			"to": "func _process(delta: float) -> void:\n\tif alert_timer > 0.0:\n\t\talert_timer = maxf(alert_timer - delta, 0.0)\n\t\tif alert_banner:\n\t\t\talert_banner.visible = alert_timer > 0.0\n\n\tif Input.is_action_just_pressed(\"switch_front\"):\n"
		},
		{
			"from": "\t_process_layer_transfers()\n\tif opening_build_active:\n\t\tif _tunnel_route_length() >= MINIMUM_OPENING_ROUTE_LENGTH:\n\t\t\t_complete_opening_build()\n\t\t_update_interface()\n\t\treturn\n",
			"to": "\t_process_layer_transfers()\n\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tif opening_route != last_opening_route_length:\n\t\t\tlast_opening_route_length = opening_route\n\t\t\t_update_opening_route_marker(opening_route)\n\t\tif opening_route >= MINIMUM_OPENING_ROUTE_LENGTH:\n\t\t\t_complete_opening_build()\n\t\t_update_interface()\n\t\treturn\n"
		},
		{
			"from": "\tcommand_message = \"BREACH: an invader transferred into the mine. Intercept it before it reaches the base.\"\n",
			"to": "\tcommand_message = \"BREACH: an invader transferred into the mine. Intercept it before it reaches the base.\"\n\t_show_alert(\"BREACH IN THE MINE\\nINTERCEPT NOW\", 1.4)\n"
		},
		{
			"from": "\tcommand_message = \"Safe route established. Hero control restored; first invasion begins after the warning clock.\"\n\t_apply_control()\n",
			"to": "\tcommand_message = \"Safe route established. Hero control restored; first invasion begins after the warning clock.\"\n\tvar opening_marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif opening_marker:\n\t\topening_marker.visible = false\n\t_show_alert(\"SAFE ROUTE ESTABLISHED\\nHERO CONTROL RESTORED\", 2.0)\n\t_apply_control()\n"
		},
		{
			"from": "func _build_portal_markers() -> void:\n\tportal_nodes[\"TunnelGate\"] = _create_world_marker",
			"to": "func _build_portal_markers() -> void:\n\tportal_nodes[\"OpeningRouteEnd\"] = _create_world_marker(\"OpeningRouteEnd\", tunnel_exit_cell, Color(1.0, 0.78, 0.2, 0.96), \"ROUTE END 1/6\", 20.0)\n\tportal_nodes[\"TunnelGate\"] = _create_world_marker"
		},
		{
			"from": "func _circle_polygon(radius: float, points: int) -> PackedVector2Array:\n",
			"to": "func _update_opening_route_marker(route_length: int) -> void:\n\tvar marker := portal_nodes.get(\"OpeningRouteEnd\") as Node2D\n\tif marker == null:\n\t\treturn\n\tmarker.global_position = _cell_world_position(_find_farthest_tunnel_cell())\n\tmarker.visible = opening_build_active\n\tvar caption := marker.get_node_or_null(\"Caption\") as Label\n\tif caption:\n\t\tcaption.text = \"ROUTE END %d/%d\" % [mini(route_length, MINIMUM_OPENING_ROUTE_LENGTH), MINIMUM_OPENING_ROUTE_LENGTH]\n\nfunc _show_alert(text: String, duration: float) -> void:\n\tif alert_banner == null or alert_label == null:\n\t\treturn\n\talert_label.text = text\n\talert_banner.visible = true\n\talert_timer = duration\n\nfunc _circle_polygon(radius: float, points: int) -> PackedVector2Array:\n"
		},
		{
			"from": "\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tmode_label.text = \"OPENING PEON • DIG SAFE ROUTE\"\n",
			"to": "\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tif opening_progress:\n\t\t\topening_progress.visible = true\n\t\t\topening_progress.max_value = MINIMUM_OPENING_ROUTE_LENGTH\n\t\t\topening_progress.value = mini(opening_route, MINIMUM_OPENING_ROUTE_LENGTH)\n\t\tmode_label.text = \"OPENING PEON • DIG SAFE ROUTE\"\n"
		},
		{
			"from": "\t\thint_label.text = command_message\n\t\treturn\n\tswitch_button.disabled = false\n",
			"to": "\t\thint_label.text = command_message\n\t\treturn\n\tif opening_progress:\n\t\topening_progress.visible = false\n\tswitch_button.disabled = false\n"
		}
	]

	for replacement in replacements:
		var from_text := str(replacement["from"])
		var to_text := str(replacement["to"])
		var count := source.count(from_text)
		if count != 1:
			push_error("Expected one controller match, found %d for: %s" % [count, from_text.left(80)])
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)

	var output := FileAccess.open(CONTROLLER_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_OPENING_POLISH_PATCH_PASS")
	get_tree().quit(0)
