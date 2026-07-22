extends Node

const MENU_PATH := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(MENU_PATH)
	if source.is_empty():
		push_error("Could not read main menu script")
		get_tree().quit(1)
		return
	var old_entry := '''func _on_online_multiplayer_pressed() -> void:
	_open_multiplayer_menu(true)
'''
	var new_entry := '''func _on_online_multiplayer_pressed() -> void:
	# Online multiplayer now begins with a private hosted stronghold instead of
	# choosing a mode in a disconnected menu first.
	GameMode.set_mode(GameMode.Mode.HUB)
	Global.apply_selected_loadout()
	get_tree().change_scene_to_file("res://online_lobby.tscn")
'''
	if not source.contains(old_entry):
		push_error("Could not find online multiplayer entry function")
		get_tree().quit(1)
		return
	source = source.replace(old_entry, new_entry)
	source = source.replace(
		'online_multiplayer_button.tooltip_text = "Play the existing WebRTC Exploration VS mode online."',
		'online_multiplayer_button.tooltip_text = "Host your stronghold with a private password or join a friend online."'
	)
	var file := FileAccess.open(MENU_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write main menu script")
		get_tree().quit(1)
		return
	file.store_string(source)
	file.close()
	print("ONLINE_STRONGHOLD_ENTRY_APPLIED")
	get_tree().quit()
