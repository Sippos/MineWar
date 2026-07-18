extends Node

const TARGET := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var input := FileAccess.open(TARGET, FileAccess.READ)
	if input == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := input.get_as_text()
	var patches: Array[Dictionary] = [
		{
			"from": "var order_marker: Node2D\nvar order_line: Line2D\n\nvar opening_build_active := true\n",
			"to": "var order_marker: Node2D\nvar order_line: Line2D\nvar touch_command_panel: PanelContainer\nvar touch_confirm_button: Button\nvar touch_cancel_button: Button\nvar touch_selection_label: Label\n\nvar opening_build_active := true\n"
		},
		{
			"from": "var active_order_target := INVALID_CELL\nvar last_breach_feedback_msec := -10000\n",
			"to": "var active_order_target := INVALID_CELL\nvar last_breach_feedback_msec := -10000\nvar touch_command_mode := false\nvar touch_target_selected := false\n"
		},
		{
			"from": "\t_build_hud()\n\t_build_command_visuals()\n\topening_topology_start = _world_topology_revision()\n",
			"to": "\t_build_hud()\n\t_build_command_visuals()\n\t_configure_pointer_mode()\n\topening_topology_start = _world_topology_revision()\n"
		},
		{
			"from": "\talert_label = hud.get_node(\"AlertBanner/Margin/Alert\") as Label\n\tbreach_flash = ColorRect.new()\n",
			"to": "\talert_label = hud.get_node(\"AlertBanner/Margin/Alert\") as Label\n\ttouch_command_panel = hud.get_node(\"TouchCommandPanel\") as PanelContainer\n\ttouch_cancel_button = hud.get_node(\"TouchCommandPanel/Margin/Row/Cancel\") as Button\n\ttouch_selection_label = hud.get_node(\"TouchCommandPanel/Margin/Row/Selection\") as Label\n\ttouch_confirm_button = hud.get_node(\"TouchCommandPanel/Margin/Row/Confirm\") as Button\n\tbreach_flash = ColorRect.new()\n"
		},
		{
			"from": "\tswitch_button.pressed.connect(_toggle_front)\n\tradar_button.pressed.connect(_begin_radar_command)\n",
			"to": "\tswitch_button.pressed.connect(_toggle_front)\n\tradar_button.pressed.connect(_begin_radar_command)\n\ttouch_cancel_button.pressed.connect(_cancel_touch_command)\n\ttouch_confirm_button.pressed.connect(_confirm_touch_command)\n"
		},
		{
			"from": "func _unhandled_input(event: InputEvent) -> void:\n\tif not command_view_active or run_finished:\n\t\treturn\n\tif event is InputEventMouseMotion:\n\t\t_update_command_preview(_viewport_to_command_cell(event.position))\n\t\treturn\n\tvar pressed_position := Vector2.ZERO\n\tvar is_command_click := false\n\tif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:\n\t\tpressed_position = event.position\n\t\tis_command_click = true\n\telif event is InputEventScreenTouch and event.pressed:\n\t\tpressed_position = event.position\n\t\tis_command_click = true\n\tif not is_command_click:\n\t\treturn\n\n\tvar target_cell := _viewport_to_command_cell(pressed_position)\n\t_update_command_preview(target_cell)\n\t_issue_command(target_cell)\n\tget_viewport().set_input_as_handled()\n\n",
			"to": "func _unhandled_input(event: InputEvent) -> void:\n\tif run_finished:\n\t\treturn\n\tvar opening_touch_active := opening_build_active and touch_command_mode\n\tif not command_view_active and not opening_touch_active:\n\t\treturn\n\tif event is InputEventMouseMotion:\n\t\tif command_view_active and not touch_command_mode:\n\t\t\t_update_command_preview(_viewport_to_command_cell(event.position))\n\t\treturn\n\tvar pressed_position := Vector2.ZERO\n\tvar is_command_click := false\n\tif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:\n\t\tpressed_position = event.position\n\t\tis_command_click = true\n\telif event is InputEventScreenTouch and event.pressed:\n\t\tpressed_position = event.position\n\t\tis_command_click = true\n\tif not is_command_click:\n\t\treturn\n\n\tvar target_cell := _viewport_to_command_cell(pressed_position)\n\t_update_command_preview(target_cell)\n\tif touch_command_mode:\n\t\t_select_touch_target(target_cell)\n\telse:\n\t\t_issue_command(target_cell)\n\tget_viewport().set_input_as_handled()\n\nfunc _configure_pointer_mode() -> void:\n\ttouch_command_mode = OS.has_feature(\"mobile\") or DisplayServer.is_touchscreen_available()\n\tif touch_command_mode:\n\t\tcommand_preview_line.width = 6.0\n\t\torder_line.width = 5.0\n\t_refresh_touch_command_panel()\n\nfunc _is_valid_command_target(cell: Vector2i) -> bool:\n\tif not _is_surface_cell(cell) or peon == null or bool(peon.call(\"is_order_active\")):\n\t\treturn false\n\tif opening_build_active:\n\t\treturn block_layer.get_cell_source_id(cell) != -1\n\tif command_mode == \"RADAR\":\n\t\treturn block_layer.get_cell_source_id(cell) == -1 and not radar_cells.has(cell)\n\treturn block_layer.get_cell_source_id(cell) != -1\n\nfunc _select_touch_target(cell: Vector2i) -> void:\n\ttouch_target_selected = _is_valid_command_target(cell)\n\tcommand_preview_cell = cell if touch_target_selected else INVALID_CELL\n\tif not touch_target_selected:\n\t\tcommand_message = \"Tap a highlighted dirt tile inside the upper LineWars field.\"\n\t_refresh_touch_command_panel()\n\t_update_interface()\n\nfunc _confirm_touch_command() -> void:\n\tif not touch_command_mode or not touch_target_selected or command_preview_cell == INVALID_CELL:\n\t\t_play_sound(\"play_error\")\n\t\treturn\n\tvar target_cell := command_preview_cell\n\ttouch_target_selected = false\n\tif opening_build_active:\n\t\tif bool(peon.call(\"issue_dig_order\", target_cell)):\n\t\t\tcommand_message = \"Safe-route dig confirmed. The peon will carve toward %s.\" % _format_cell(target_cell)\n\t\t\t_show_order_visual(target_cell, \"DIG\")\n\t\t\t_play_sound(\"play_purchase\")\n\t\telse:\n\t\t\t_play_sound(\"play_error\")\n\telse:\n\t\t_issue_command(target_cell)\n\t_refresh_touch_command_panel()\n\nfunc _cancel_touch_command() -> void:\n\ttouch_target_selected = false\n\tcommand_preview_cell = INVALID_CELL\n\tif command_cursor:\n\t\tcommand_cursor.visible = false\n\tif command_preview_line:\n\t\tcommand_preview_line.visible = false\n\tif opening_build_active:\n\t\tcommand_message = \"Tap dirt to plan the safe route, or steer the peon normally.\"\n\t\t_refresh_touch_command_panel()\n\t\t_update_interface()\n\telse:\n\t\t_exit_command_view()\n\nfunc _refresh_touch_command_panel() -> void:\n\tif touch_command_panel == null:\n\t\treturn\n\tvar should_show := touch_command_mode and (opening_build_active or command_view_active)\n\ttouch_command_panel.visible = should_show\n\tif not should_show:\n\t\treturn\n\ttouch_cancel_button.text = \"CLEAR\" if opening_build_active else \"CANCEL\"\n\ttouch_confirm_button.text = \"DIG SAFE ROUTE\" if opening_build_active else (\"CONFIRM RADAR\" if command_mode == \"RADAR\" else \"CONFIRM TUNNEL\")\n\ttouch_confirm_button.disabled = not touch_target_selected or bool(peon.call(\"is_order_active\"))\n\tif bool(peon.call(\"is_order_active\")):\n\t\ttouch_selection_label.text = \"PEON WORKING…\"\n\telif touch_target_selected:\n\t\ttouch_selection_label.text = \"TARGET %s\" % _format_cell(command_preview_cell)\n\telse:\n\t\ttouch_selection_label.text = \"TAP DIRT TO PLAN\" if opening_build_active or command_mode == \"DIG\" else \"TAP OPEN TUNNEL\"\n\n"
		},
		{
			"from": "func _begin_command_view(mode: String) -> void:\n\tcommand_view_active = true\n\tcommand_mode = mode\n\tcommand_message = (\n\t\t\"Click one open tunnel tile. The peon will walk there and install the radar.\"\n\t\tif mode == \"RADAR\"\n\t\telse\n\t\t\"Click one distant dirt block. The peon will dig an L-shaped tunnel to it, then remain there for the next order.\"\n\t)\n\t_apply_control()\n\t_update_command_preview(_viewport_to_command_cell(get_viewport().get_mouse_position()))\n\t_update_interface()\n",
			"to": "func _begin_command_view(mode: String) -> void:\n\tcommand_view_active = true\n\tcommand_mode = mode\n\ttouch_target_selected = false\n\tcommand_preview_cell = INVALID_CELL\n\tcommand_message = (\n\t\t(\"Tap an open tunnel tile, then confirm the radar order.\" if touch_command_mode else \"Click one open tunnel tile. The peon will walk there and install the radar.\")\n\t\tif mode == \"RADAR\"\n\t\telse\n\t\t(\"Tap dirt to preview a route, then confirm it.\" if touch_command_mode else \"Click one distant dirt block. The peon will dig an L-shaped tunnel to it, then remain there for the next order.\")\n\t)\n\t_apply_control()\n\tif not touch_command_mode:\n\t\t_update_command_preview(_viewport_to_command_cell(get_viewport().get_mouse_position()))\n\t_refresh_touch_command_panel()\n\t_update_interface()\n"
		},
		{
			"from": "func _exit_command_view() -> void:\n\tcommand_view_active = false\n\tcommand_mode = \"DIG\"\n\tcommand_preview_cell = INVALID_CELL\n",
			"to": "func _exit_command_view() -> void:\n\tcommand_view_active = false\n\tcommand_mode = \"DIG\"\n\ttouch_target_selected = false\n\tcommand_preview_cell = INVALID_CELL\n"
		},
		{
			"from": "\t_apply_control()\n\t_update_interface()\n\nfunc _apply_control() -> void:\n",
			"to": "\t_apply_control()\n\t_refresh_touch_command_panel()\n\t_update_interface()\n\nfunc _apply_control() -> void:\n"
		},
		{
			"from": "\t_play_sound(\"play_upgrade\")\n\t_apply_control()\n\nfunc _on_peon_work_order_finished",
			"to": "\t_play_sound(\"play_upgrade\")\n\t_apply_control()\n\t_refresh_touch_command_panel()\n\nfunc _on_peon_work_order_finished"
		},
		{
			"from": "func _on_peon_work_order_finished(kind: String, cell: Vector2i) -> void:\n\t_hide_order_visual()\n\t_play_sound(\"play_deposit\")\n",
			"to": "func _on_peon_work_order_finished(kind: String, cell: Vector2i) -> void:\n\t_hide_order_visual()\n\t_play_sound(\"play_deposit\")\n\ttouch_target_selected = false\n\tif opening_build_active:\n\t\t_apply_control()\n"
		},
		{
			"from": "\t_update_interface()\n\nfunc _on_peon_work_order_failed(message: String) -> void:\n",
			"to": "\t_refresh_touch_command_panel()\n\t_update_interface()\n\nfunc _on_peon_work_order_failed(message: String) -> void:\n"
		},
		{
			"from": "func _update_command_preview(cell: Vector2i) -> void:\n\tcommand_preview_cell = cell\n\tif command_cursor == null or command_preview_line == null or peon == null:\n\t\treturn\n\tvar valid := _is_surface_cell(cell)\n\tif valid and command_mode == \"RADAR\":\n\t\tvalid = block_layer.get_cell_source_id(cell) == -1 and not radar_cells.has(cell)\n\telif valid:\n\t\tvalid = block_layer.get_cell_source_id(cell) != -1\n",
			"to": "func _update_command_preview(cell: Vector2i) -> void:\n\tcommand_preview_cell = cell\n\tif command_cursor == null or command_preview_line == null or peon == null:\n\t\treturn\n\tvar valid := _is_valid_command_target(cell)\n"
		},
		{
			"from": "func _update_interface() -> void:\n\tif mode_label == null or threat_label == null or hint_label == null or switch_button == null or radar_button == null:\n\t\treturn\n\n",
			"to": "func _update_interface() -> void:\n\tif mode_label == null or threat_label == null or hint_label == null or switch_button == null or radar_button == null:\n\t\treturn\n\t_refresh_touch_command_panel()\n\n"
		},
		{
			"from": "\t\thint_label.text = command_message\n\t\treturn\n",
			"to": "\t\thint_label.text = command_message\n\t\tif touch_command_mode:\n\t\t\thint_label.text += \"  •  Tap a dirt tile, then press DIG SAFE ROUTE.\"\n\t\treturn\n"
		},
		{
			"from": "\tif command_view_active:\n\t\thint_label.text += \"  •  Move the cursor to preview the order; click to confirm. Tab / RB cancels.\"\n",
			"to": "\tif command_view_active:\n\t\thint_label.text += (\"  •  Tap a tile, then use the large confirm button.\" if touch_command_mode else \"  •  Move the cursor to preview the order; click to confirm. Tab / RB cancels.\")\n"
		}
	]

	for patch in patches:
		var from_text: String = patch["from"]
		var to_text: String = patch["to"]
		var count := source.count(from_text)
		if count != 1:
			push_error("Touch patch mismatch: expected 1, found %d for: %s" % [count, from_text.left(80)])
			get_tree().quit(1)
			return
		source = source.replace(from_text, to_text)

	var output := FileAccess.open(TARGET, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_TOUCH_CONTROLS_PATCH_PASS")
	get_tree().quit(0)
