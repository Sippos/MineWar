extends Node

const TARGET := "res://scripts/systems/continuous_line_wars_controller.gd"
const MARKER := "func _update_interface() -> void:\n"

func _ready() -> void:
	var file := FileAccess.open(TARGET, FileAccess.READ)
	if file == null:
		push_error("Could not read LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var marker_index := source.find(MARKER)
	if marker_index < 0:
		push_error("Could not find LineWars interface marker")
		get_tree().quit(1)
		return
	var prefix := source.substr(0, marker_index)
	var tail := """func _update_interface() -> void:
	if mode_label == null or threat_label == null or hint_label == null or switch_button == null or radar_button == null:
		return

	var peon_status := str(peon.call("get_order_progress_text")) if peon else "IDLE"
	if opening_build_active:
		var newly_dug_tiles := _opening_new_tiles_dug()
		if opening_progress:
			opening_progress.visible = true
			opening_progress.max_value = OPENING_REQUIRED_NEW_TILES
			opening_progress.value = mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES)
		if touch_action_panel:
			touch_action_panel.visible = false
		mode_label.text = "OPENING PEON • BUILD SAFE ROUTE"
		switch_button.text = "TUNNEL %d/%d" % [mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]
		switch_button.disabled = true
		radar_button.text = "RADAR LOCKED"
		radar_button.disabled = true
		threat_label.text = "WAVES PAUSED • DIG %d MORE" % maxi(OPENING_REQUIRED_NEW_TILES - newly_dug_tiles, 0)
		hint_label.text = command_message
		if touch_command_mode:
			hint_label.text += "  •  Tap roughly beside the peon to carve one adjacent block; the game chooses the nearest valid direction."
		return

	if opening_progress:
		opening_progress.visible = false
	if touch_action_panel:
		touch_action_panel.visible = touch_command_mode and command_view_active
	switch_button.disabled = false
	mode_label.text = "PEON COMMAND • %s" % command_mode if command_view_active else "HERO • MINE & INTERCEPT"
	switch_button.text = "RETURN TO HERO" if command_view_active else ("VIEW PEON • %s" % peon_status if peon_status != "IDLE" else "COMMAND PEON")
	radar_button.text = "RADAR %d/%d • %d GEM" % [radar_cells.size(), MAX_RADARS, RADAR_COST]
	radar_button.disabled = command_view_active or bool(peon.call("is_order_active")) or radar_cells.size() >= MAX_RADARS or _available_gems() < RADAR_COST

	var radar_contacts := _radar_contact_count()
	if vs_match_gate_enabled and not vs_match_started:
		threat_label.text = "READY • WAITING FOR OPPONENT"
	elif not vs_active_payload.is_empty():
		threat_label.text = "INCOMING %s • %.1fs • QUEUE %d" % [str(vs_active_payload.get("label", "SEND")), vs_incoming_warning_timer, vs_incoming_queue.size()]
	elif spawning:
		threat_label.text = "RADAR ALERT • WAVE %d • PORTAL %s • %.1fs" % [current_wave, _format_cell(last_spawn_cell), current_telegraph_duration]
	elif wave_in_progress:
		threat_label.text = "WAVE %d • TUNNEL %d • MINE %d" % [current_wave, _count_enemies_in_layer("tunnel"), _count_enemies_in_layer("mine")]
		if radar_contacts > 0:
			threat_label.text += " • RADAR %d" % radar_contacts
	elif _count_world_enemies() > 0:
		threat_label.text = "VS PRESSURE • TUNNEL %d • MINE %d" % [_count_enemies_in_layer("tunnel"), _count_enemies_in_layer("mine")]
	else:
		threat_label.text = "WAVE %d IN %ds • ROUTE %d • RADARS %d" % [next_wave, int(ceil(invasion_timer)), _tunnel_route_length(), radar_cells.size()]

	hint_label.text = command_message
	if command_view_active:
		if touch_command_mode:
			hint_label.text += "  •  Tap to select, then use the large confirm button. No precise dragging required."
		else:
			hint_label.text += "  •  Move the cursor to preview the order; click to confirm. Tab / RB cancels."
	elif wave_in_progress or _count_world_enemies() > 0:
		hint_label.text += "  •  Orange gate transfers tunnel survivors to the blue mine gate; leaks that reach the base deal damage."

func _tunnel_route_length() -> int:
	var endpoint := _find_farthest_tunnel_cell()
	if endpoint == tunnel_exit_cell:
		return 1
	if world.get("astar") == null:
		return 1
	var path: Array[Vector2i] = world.astar.get_id_path(tunnel_exit_cell, endpoint)
	return maxi(path.size(), 1)

func _available_gems() -> int:
	if world_hud == null:
		return 0
	var value: Variant = world_hud.get("total_gems")
	return int(value) if value != null else 0

func _spend_gems(amount: int) -> void:
	if world_hud and world_hud.has_method("add_gems"):
		world_hud.call("add_gems", -amount)

func _cell_world_position(cell: Vector2i) -> Vector2:
	return block_layer.to_global(block_layer.map_to_local(cell))

func _format_cell(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _finish_run(victory: bool) -> void:
	if run_finished:
		return
	run_finished = true
	spawning = false
	wave_in_progress = false
	command_view_active = false
	touch_selected_cell = INVALID_CELL
	if touch_action_panel:
		touch_action_panel.visible = false
	_hide_order_visual()
	_apply_control()
	if threat_label:
		threat_label.text = "LINEWARS COMPLETE" if victory else "BASE DESTROYED"
	if vs_match_gate_enabled:
		vs_run_finished.emit(vs_side_label, victory, int(base.get("health")) if base else 0)
	if hint_label:
		hint_label.text = (
			"Victory: the commissioned tunnel bought time, radar warned the hero, and the mine held every breach."
			if victory
			else
			"Defeat: too many mine survivors reached the base. Extend the tunnel and intercept breaches earlier."
		)

func _surface_movement_bounds() -> Rect2:
	var top_left := _cell_world_position(SURFACE_MIN_CELL) - Vector2(28, 28)
	var bottom_right := _cell_world_position(SURFACE_MAX_CELL) + Vector2(28, 28)
	return Rect2(top_left, bottom_right - top_left)

func _ensure_switch_action() -> void:
	if not InputMap.has_action("switch_front"):
		InputMap.add_action("switch_front")
	var has_tab := false
	var has_shoulder := false
	for existing in InputMap.action_get_events("switch_front"):
		if existing is InputEventKey and existing.physical_keycode == KEY_TAB:
			has_tab = true
		elif existing is InputEventJoypadButton and existing.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			has_shoulder = true
	if not has_tab:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_TAB
		InputMap.action_add_event("switch_front", key_event)
	if not has_shoulder:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("switch_front", joy_event)
"""
	var output := FileAccess.open(TARGET, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(prefix + tail)
	print("LINEWARS_VS_TAIL_REPAIR_PASS")
	get_tree().quit(0)
