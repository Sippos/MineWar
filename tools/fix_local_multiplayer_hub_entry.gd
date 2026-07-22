extends SceneTree

const CONTROLLER_PATH := "res://scripts/systems/preparation/local_multiplayer_hub_controller.gd"

func _initialize() -> void:
	var file := FileAccess.open(CONTROLLER_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read local multiplayer hub controller")
		quit(1)
		return
	var source := file.get_as_text()
	file.close()

	source = source.replace("var _last_status := \"\"\n", "var _last_status := \"\"\nvar _routes_armed := false\n")
	source = source.replace("player_one.position = Vector2(-38, 150)", "player_one.position = Vector2(-38, 72)")
	source = source.replace("player_two.position = Vector2(38, 150)", "player_two.position = Vector2(38, 72)")

	var old_block := '''func _update_readiness(delta: float) -> void:
	var p1_mode := _mode_zone_for(player_one)
	var p2_mode := _mode_zone_for(player_two)
	if not p1_mode.is_empty() and p1_mode == p2_mode:
'''
	var new_block := '''func _update_readiness(delta: float) -> void:
	var p1_mode := _mode_zone_for(player_one)
	var p2_mode := _mode_zone_for(player_two)
	if not _routes_armed:
		if p1_mode.is_empty() and p2_mode.is_empty():
			_routes_armed = true
			_set_status("Choose heroes independently, then enter the same route together.  P1: WASD  •  P2: Arrow Keys")
		else:
			_set_status("Shared stronghold ready  •  Move into the hall, then choose a route together.")
		return
	if not p1_mode.is_empty() and p1_mode == p2_mode:
'''
	if not source.contains(old_block):
		push_error("Could not find readiness block")
		quit(1)
		return
	source = source.replace(old_block, new_block)

	var out := FileAccess.open(CONTROLLER_PATH, FileAccess.WRITE)
	if out == null:
		push_error("Could not write local multiplayer hub controller")
		quit(1)
		return
	out.store_string(source)
	out.close()
	print("LOCAL_MULTIPLAYER_ENTRY_FIXED")
	quit()
