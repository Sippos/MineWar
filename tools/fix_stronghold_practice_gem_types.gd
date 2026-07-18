extends Node

func _ready() -> void:
	var path := "res://scripts/systems/stronghold_practice_gem_controller.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read practice gem controller")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	source = source.replace(
		"\t\t\tvar near := player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS\n\t\t\tvar seconds := _current_dig_duration()\n",
		"\t\t\tvar near: bool = player.global_position.distance_to(get_practice_vein_position()) <= DIG_RADIUS\n\t\t\tvar seconds: float = _current_dig_duration()\n"
	)
	source = source.replace(
		"\t\t\tvar carried := practice_gem != null and is_instance_valid(practice_gem) and practice_gem.get(\"tethered_to\") == player\n\t\t\tif carried:\n\t\t\t\tvar penalty := int(round(float(player.call(\"get_weight_penalty\")) * 100.0)) if player.has_method(\"get_weight_penalty\") else 0\n\t\t\t\tvar drop_action := \"DROP AT CART • E / B\" if player.global_position.distance_to(RECEIVER_POSITION) <= RECEIVER_RADIUS else \"DENSE GEM • %d%% SLOW • Carry it to the cart\" % penalty\n",
		"\t\t\tvar carried: bool = practice_gem != null and is_instance_valid(practice_gem) and practice_gem.get(\"tethered_to\") == player\n\t\t\tif carried:\n\t\t\t\tvar penalty: int = int(round(float(player.call(\"get_weight_penalty\")) * 100.0)) if player.has_method(\"get_weight_penalty\") else 0\n\t\t\t\tvar drop_action: String = \"DROP AT CART • E / B\" if player.global_position.distance_to(RECEIVER_POSITION) <= RECEIVER_RADIUS else \"DENSE GEM • %d%% SLOW • Carry it to the cart\" % penalty\n"
	)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write practice gem controller")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("STRONGHOLD_PRACTICE_GEM_TYPES_FIXED")
	get_tree().quit()
