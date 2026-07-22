extends Node

func _ready() -> void:
	var config := ConfigFile.new()
	config.load("user://minewars_settings.cfg")
	config.set_value("display", "window_mode", 0)
	config.save("user://minewars_settings.cfg")
	print("SETTINGS_TEST_STATE_RESET")
	get_tree().quit(0)
