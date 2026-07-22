extends Node

const MENU_PATH := "res://scripts/ui/menus/main/menu.gd"

func _ready() -> void:
	var file := FileAccess.open(MENU_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read main menu script")
		get_tree().quit(1)
		return
	var source := file.get_as_text()
	file.close()
	var old_block := "func _on_local_multiplayer_pressed() -> void:\n\t_open_multiplayer_menu(false)\n"
	var new_block := "func _on_local_multiplayer_pressed() -> void:\n\t# Local multiplayer begins inside the shared physical stronghold.\n\tGameMode.set_mode(GameMode.Mode.HUB)\n\tGlobal.apply_selected_loadout()\n\tget_tree().change_scene_to_file(\"res://scenes/world/preparation/local_multiplayer_hub.tscn\")\n"
	if not source.contains(old_block):
		push_error("Local multiplayer menu entry block was not found")
		get_tree().quit(2)
		return
	source = source.replace(old_block, new_block)
	file = FileAccess.open(MENU_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write main menu script")
		get_tree().quit(3)
		return
	file.store_string(source)
	file.close()
	print("LOCAL_MULTIPLAYER_HUB_PATCH_APPLIED")
	get_tree().quit(0)
