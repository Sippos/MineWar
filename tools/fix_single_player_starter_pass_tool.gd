extends Node

const TARGET := "res://tools/apply_single_player_starter_hud_pass.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	if source.is_empty():
		push_error("Could not read starter HUD pass tool")
		get_tree().quit(1)
		return

	source = source.replace("\tok = _patch_compact_world() and ok\n", "\t# Compact cave constants were applied by the first pass attempt.\n\tok = true and ok\n")

	var start := source.find("func _patch_hub_controller() -> bool:")
	var finish := source.find("func _patch_siege_controller() -> bool:", start)
	if start < 0 or finish < 0:
		push_error("Could not locate hub patch function")
		get_tree().quit(1)
		return
	var replacement := '''func _patch_hub_controller() -> bool:
	var source := _read(HUB_CONTROLLER)
	if not source.contains("player.position = Vector2(0, 105)"):
		push_error("Missing compact player spawn anchor")
		return false
	source = source.replace("player.position = Vector2(0, 105)", "player.position = Vector2(0, 84)")
	if not source.contains("hub_camera.position = Vector2(0, 20)\n\thub_camera.zoom = Vector2(0.96, 0.96)"):
		push_error("Missing cozy hub camera anchor")
		return false
	source = source.replace(
		"hub_camera.position = Vector2(0, 20)\n\thub_camera.zoom = Vector2(0.96, 0.96)",
		"hub_camera.position = Vector2(0, 12)\n\thub_camera.zoom = Vector2(1.08, 1.08)"
	)
	var old_sign := ''' + "'''" + '''mine_wars.text = "EXPEDITION SHAFT
DESCEND TO MINEWARS"''' + "'''" + '''
	if not source.contains(old_sign):
		push_error("Missing expedition sign anchor")
		return false
	source = source.replace(old_sign, 'mine_wars.text = "EXPEDITION SHAFT"')
	if not source.contains("mine_wars.position = Vector2(-125, 214)\n\t\tmine_wars.size = Vector2(250, 62)"):
		push_error("Missing compact expedition sign layout anchor")
		return false
	source = source.replace(
		"mine_wars.position = Vector2(-125, 214)\n\t\tmine_wars.size = Vector2(250, 62)",
		"mine_wars.position = Vector2(-125, 220)\n\t\tmine_wars.size = Vector2(250, 34)"
	)
	return _write(HUB_CONTROLLER, source)

'''
	source = source.substr(0, start) + replacement + source.substr(finish)

	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write starter HUD pass tool")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("STARTER_HUD_PASS_TOOL_FIXED")
	get_tree().quit()
