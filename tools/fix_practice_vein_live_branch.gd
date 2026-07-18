extends Node

func _ready() -> void:
	var path := "res://scripts/systems/stronghold_practice_gem_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open practice controller")
		get_tree().quit(1)
		return
	var text := file.get_as_text()
	file.close()
	var old := "func _process_vein(delta: float) -> void:\n\tvar near_vein := player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS\n\tvar dig_action := \"p%d_dig\" % maxi(1, int(player.get(\"player_id\")))\n\tif near_vein and InputMap.has_action(dig_action) and Input.is_action_pressed(dig_action):\n\t\tdig_progress = minf(1.0, dig_progress + delta / _current_dig_duration())\n\t\t_update_dig_visuals()\n\t\tif dig_progress >= 1.0:\n\t\t\t_break_practice_vein()\n\telse:\n\t\tdig_progress = maxf(0.0, dig_progress - delta * 1.8)\n\t\t_update_dig_visuals()\n"
	var replacement := "func _process_vein(delta: float) -> void:\n\tvar near_vein: bool = player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS\n\tif near_vein and _is_pressing_toward_vein():\n\t\tdig_progress = minf(1.0, dig_progress + delta / _current_dig_duration())\n\t\t_update_dig_visuals()\n\t\tif dig_progress >= 1.0:\n\t\t\t_break_practice_vein()\n\telse:\n\t\tdig_progress = maxf(0.0, dig_progress - delta * 1.8)\n\t\t_update_dig_visuals()\n"
	var count := text.count(old)
	if count != 1:
		push_error("Practice vein branch patch expected 1 match, found %d" % count)
		get_tree().quit(1)
		return
	text = text.replace(old, replacement)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write practice controller")
		get_tree().quit(1)
		return
	file.store_string(text)
	file.close()
	print("PRACTICE_VEIN_LIVE_BRANCH_FIXED")
	get_tree().quit()
