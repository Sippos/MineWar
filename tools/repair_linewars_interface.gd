extends Node

const TARGET_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"

func _ready() -> void:
	var file := FileAccess.open(TARGET_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open LineWars controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	var start_marker := "func _update_interface() -> void:\n"
	var end_marker := "func _tunnel_route_length() -> int:\n"
	var start_index := source.find(start_marker)
	var end_index := source.find(end_marker, start_index)
	if start_index < 0 or end_index < 0:
		push_error("Could not locate LineWars interface block")
		get_tree().quit(1)
		return
	var replacement := """func _update_interface() -> void:
	if mode_label == null or threat_label == null or hint_label == null or switch_button == null or radar_button == null:
		return

	var peon_status := str(peon.call("get_order_progress_text")) if peon else "IDLE"
	if opening_build_active:
		var newly_dug_tiles := _opening_new_tiles_dug()
		if opening_progress:
			opening_progress.visible = true
			opening_progress.max_value = OPENING_REQUIRED_NEW_TILES
			opening_progress.value = mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES)
		mode_label.text = "OPENING PEON • BUILD SAFE ROUTE"
		switch_button.text = "TUNNEL %d/%d" % [mini(newly_dug_tiles, OPENING_REQUIRED_NEW_TILES), OPENING_REQUIRED_NEW_TILES]
		switch_button.disabled = true
		radar_button.text = "RADAR LOCKED"
		radar_button.disabled = true
		threat_label.text = "WAVES PAUSED • DIG %d MORE" % maxi(OPENING_REQUIRED_NEW_TILES - newly_dug_tiles, 0)
		hint_label.text = command_message
		return

	if opening_progress:
		opening_progress.visible = false
	switch_button.disabled = false
	mode_label.text = "PEON COMMAND • %s" % command_mode if command_view_active else "HERO • MINE & INTERCEPT"
	switch_button.text = "RETURN TO HERO" if command_view_active else ("VIEW PEON • %s" % peon_status if peon_status != "IDLE" else "COMMAND PEON")
	radar_button.text = "RADAR %d/%d • %d GEM" % [radar_cells.size(), MAX_RADARS, RADAR_COST]
	radar_button.disabled = command_view_active or bool(peon.call("is_order_active")) or radar_cells.size() >= MAX_RADARS or _available_gems() < RADAR_COST

	var radar_contacts := _radar_contact_count()
	if spawning:
		threat_label.text = "RADAR ALERT • WAVE %d • PORTAL %s • %.1fs" % [current_wave, _format_cell(last_spawn_cell), current_telegraph_duration]
	elif wave_in_progress:
		threat_label.text = "WAVE %d • TUNNEL %d • MINE %d" % [current_wave, _count_enemies_in_layer("tunnel"), _count_enemies_in_layer("mine")]
		if radar_contacts > 0:
			threat_label.text += " • RADAR %d" % radar_contacts
	else:
		threat_label.text = "WAVE %d IN %ds • ROUTE %d • RADARS %d" % [next_wave, int(ceil(invasion_timer)), _tunnel_route_length(), radar_cells.size()]

	hint_label.text = command_message
	if command_view_active:
		hint_label.text += "  •  Move the cursor to preview the order; click to confirm. Tab / RB cancels."
	elif wave_in_progress:
		hint_label.text += "  •  Orange gate transfers tunnel survivors to the blue mine gate; leaks that reach the base deal damage."

"""
	source = source.left(start_index) + replacement + source.substr(end_index)
	var output := FileAccess.open(TARGET_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write LineWars controller")
		get_tree().quit(1)
		return
	output.store_string(source)
	print("LINEWARS_INTERFACE_REPAIR_PASS")
	get_tree().quit(0)
