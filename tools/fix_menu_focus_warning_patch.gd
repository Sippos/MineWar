extends Node

const PATH := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(PATH)
	var old_multiplayer := '''	multiplayer_menu.tree_exited.connect(func():
		if is_instance_valid(self):
			(local_multiplayer_button if not use_online_mode else online_multiplayer_button).grab_focus()
	)
'''
	var new_multiplayer := '''	multiplayer_menu.tree_exited.connect(func():
		if not is_instance_valid(self) or not is_inside_tree():
			return
		var target := local_multiplayer_button if not use_online_mode else online_multiplayer_button
		if is_instance_valid(target) and target.is_inside_tree():
			target.grab_focus()
	)
'''
	var old_controls := '''	controls.tree_exited.connect(func(): controls_button.grab_focus())
'''
	var new_controls := '''	controls.tree_exited.connect(func():
		if is_instance_valid(controls_button) and controls_button.is_inside_tree():
			controls_button.grab_focus()
	)
'''
	var old_settings := '''	settings.tree_exited.connect(func(): settings_button.grab_focus())
'''
	var new_settings := '''	settings.tree_exited.connect(func():
		if is_instance_valid(settings_button) and settings_button.is_inside_tree():
			settings_button.grab_focus()
	)
'''
	if not source.contains(old_multiplayer):
		push_error("Multiplayer focus target missing")
		get_tree().quit(1)
		return
	source = source.replace(old_multiplayer, new_multiplayer)
	source = source.replace(old_controls, new_controls)
	source = source.replace(old_settings, new_settings)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	print("FIX_MENU_FOCUS_WARNING_PATCH_OK")
	get_tree().quit(0)
