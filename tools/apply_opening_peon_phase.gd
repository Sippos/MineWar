extends Node

const CONTROLLER_PATH := "res://scripts/systems/continuous_line_wars_controller.gd"
const HUB_CONTROLLER_PATH := "res://scripts/systems/single_player_world_controller.gd"

func _ready() -> void:
	var failures := 0
	failures += _patch_controller()
	failures += _patch_hub_message()
	if failures == 0:
		print("OPENING_PEON_PHASE_PATCH_PASS")
		get_tree().quit(0)
	else:
		push_error("OPENING_PEON_PHASE_PATCH_FAIL: %d replacements failed" % failures)
		get_tree().quit(1)

func _patch_controller() -> int:
	var source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	if source.is_empty():
		push_error("Could not read " + CONTROLLER_PATH)
		return 1
	var failures := 0
	failures += _replace_required(source,
		"const FIRST_INVASION_DELAY := 28.0\nconst INVASION_INTERVAL := 24.0",
		"const FIRST_INVASION_DELAY := 28.0\nconst MINIMUM_OPENING_ROUTE_LENGTH := 6\nconst INVASION_INTERVAL := 24.0")
	source = _last_result
	failures += _replace_required(source,
		"var command_view_active := false\nvar command_mode := \"DIG\"",
		"var opening_build_active := true\nvar command_view_active := false\nvar command_mode := \"DIG\"")
	source = _last_result
	failures += _replace_required(source,
		"\t_build_hud()\n\t_apply_control()\n\tcommand_message = \"Mine below with the hero. Command the peon only when you want to extend the delay tunnel.\"",
		"\t_build_hud()\n\t_apply_control()\n\tcommand_message = \"Opening build: directly control the peon and dig upward until the safe-route meter is full. Waves are paused.\"")
	source = _last_result
	failures += _replace_required(source,
		"\t_process_layer_transfers()\n\tif wave_in_progress:",
		"\t_process_layer_transfers()\n\tif opening_build_active:\n\t\tif _tunnel_route_length() >= MINIMUM_OPENING_ROUTE_LENGTH:\n\t\t\t_complete_opening_build()\n\t\t_update_interface()\n\t\treturn\n\tif wave_in_progress:")
	source = _last_result
	failures += _replace_required(source,
		"func _toggle_front() -> void:\n\tif run_finished:\n\t\treturn",
		"func _toggle_front() -> void:\n\tif run_finished:\n\t\treturn\n\tif opening_build_active:\n\t\tcommand_message = \"Dig the minimum opening route first. Waves remain paused until the meter is full.\"\n\t\t_update_interface()\n\t\treturn")
	source = _last_result
	failures += _replace_required(source,
		"func _begin_radar_command() -> void:\n\tif run_finished:\n\t\treturn",
		"func _begin_radar_command() -> void:\n\tif run_finished:\n\t\treturn\n\tif opening_build_active:\n\t\tcommand_message = \"Finish the minimum tunnel before installing infrastructure.\"\n\t\t_update_interface()\n\t\treturn")
	source = _last_result
	failures += _replace_required(source,
		"func _apply_control() -> void:\n\tif peon == null or hero == null:\n\t\treturn\n\t# Command view is deliberately temporary. The peon is never directly driven;\n\t# after one click, the hero immediately resumes mining and combat below.\n\tpeon.call(\"set_controlled\", false)\n\tpeon.call(\"set_command_camera_enabled\", command_view_active)\n\tpeon.visible = true\n\n\thero.velocity = Vector2.ZERO\n\thero.visible = true\n\thero.process_mode = Node.PROCESS_MODE_DISABLED if command_view_active else Node.PROCESS_MODE_INHERIT\n\tvar hero_camera := hero.get_node_or_null(\"Camera2D\") as Camera2D\n\tif hero_camera:\n\t\thero_camera.enabled = not command_view_active\n\t\tif not command_view_active:\n\t\t\thero_camera.reset_smoothing()",
		"func _apply_control() -> void:\n\tif peon == null or hero == null:\n\t\treturn\n\t# Only the opening build uses direct peon control. After the safe minimum route\n\t# exists, the hero owns continuous play and later peon work is commissioned.\n\tvar peon_direct_control := opening_build_active\n\tvar peon_camera_active := opening_build_active or command_view_active\n\tpeon.call(\"set_controlled\", peon_direct_control)\n\tpeon.call(\"set_command_camera_enabled\", peon_camera_active)\n\tpeon.visible = true\n\n\thero.velocity = Vector2.ZERO\n\thero.visible = true\n\thero.process_mode = Node.PROCESS_MODE_DISABLED if peon_camera_active else Node.PROCESS_MODE_INHERIT\n\tvar hero_camera := hero.get_node_or_null(\"Camera2D\") as Camera2D\n\tif hero_camera:\n\t\thero_camera.enabled = not peon_camera_active\n\t\tif not peon_camera_active:\n\t\t\thero_camera.reset_smoothing()\n\nfunc _complete_opening_build() -> void:\n\tif not opening_build_active:\n\t\treturn\n\topening_build_active = false\n\tcommand_view_active = false\n\tinvasion_timer = FIRST_INVASION_DELAY\n\tcommand_message = \"Safe route established. Hero control restored; first invasion begins after the warning clock.\"\n\t_apply_control()")
	source = _last_result
	failures += _replace_required(source,
		"\tvar peon_status := str(peon.call(\"get_order_progress_text\")) if peon else \"IDLE\"\n\tmode_label.text = (",
		"\tvar peon_status := str(peon.call(\"get_order_progress_text\")) if peon else \"IDLE\"\n\tif opening_build_active:\n\t\tvar opening_route := _tunnel_route_length()\n\t\tmode_label.text = \"OPENING PEON • DIG SAFE ROUTE\"\n\t\tswitch_button.text = \"ROUTE %d/%d\" % [mini(opening_route, MINIMUM_OPENING_ROUTE_LENGTH), MINIMUM_OPENING_ROUTE_LENGTH]\n\t\tswitch_button.disabled = true\n\t\tradar_button.text = \"RADAR LOCKED • FINISH ROUTE\"\n\t\tradar_button.disabled = true\n\t\tthreat_label.text = \"WAVES PAUSED • DIG %d MORE\" % maxi(MINIMUM_OPENING_ROUTE_LENGTH - opening_route, 0)\n\t\thint_label.text = command_message\n\t\treturn\n\tswitch_button.disabled = false\n\tmode_label.text = (")
	source = _last_result
	if failures == 0:
		var file := FileAccess.open(CONTROLLER_PATH, FileAccess.WRITE)
		file.store_string(source)
	return failures

func _patch_hub_message() -> int:
	var source := FileAccess.get_file_as_string(HUB_CONTROLLER_PATH)
	if source.is_empty():
		push_error("Could not read " + HUB_CONTROLLER_PATH)
		return 1
	var failures := _replace_required(source,
		"\t_prepare_world_for_run(\"LineWars reached — control switched to the peon. Tab / RB returns to the hero.\")",
		"\t_prepare_world_for_run(\"LineWars reached — dig a minimum opening tunnel with the peon; waves stay paused until it is safe.\")")
	source = _last_result
	if failures == 0:
		var file := FileAccess.open(HUB_CONTROLLER_PATH, FileAccess.WRITE)
		file.store_string(source)
	return failures

var _last_result := ""

func _replace_required(source: String, from_text: String, to_text: String) -> int:
	if not source.contains(from_text):
		push_error("Required patch text was not found: " + from_text.left(80))
		_last_result = source
		return 1
	_last_result = source.replace(from_text, to_text)
	return 0
