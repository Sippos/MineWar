extends Node

const TARGET := "res://scripts/systems/preparation/online_multiplayer_hub_controller.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(TARGET)
	source = source.replace("\t\tvar host_selected := host_hero == hero_name\n", "\t\tvar host_selected: bool = host_hero == hero_name\n")
	source = source.replace("\t\tvar guest_selected := guest_hero == hero_name\n", "\t\tvar guest_selected: bool = guest_hero == hero_name\n")
	var file := FileAccess.open(TARGET, FileAccess.WRITE)
	if file == null:
		push_error("Could not write online hub controller")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("ONLINE_HUB_TYPES_FIXED")
	get_tree().quit()
