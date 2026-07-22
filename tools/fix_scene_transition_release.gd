extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch_online_lobby()
	_patch_pause_menu()
	_patch_bestiary()
	if failures.is_empty():
		print("FIX_SCENE_TRANSITION_RELEASE_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_online_lobby() -> void:
	var path := "res://online_lobby.gd"
	var source := FileAccess.get_file_as_string(path)
	if not source.contains("var leaving_lobby := false"):
		source = source.replace("var connecting := false\n", "var connecting := false\nvar leaving_lobby := false\n")
	var old := '''func _on_back_pressed() -> void:
	connecting = false
	if ws:
		ws.close()
	if Global.rtc_peer:
		Global.rtc_peer.close()
	Global.rtc_peer = null
	Global.rtc_conn = null
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
'''
	var new := '''func _on_back_pressed() -> void:
	if leaving_lobby:
		return
	leaving_lobby = true
	connecting = false
	if ws:
		ws.close()
	if Global.rtc_peer:
		Global.rtc_peer.close()
	Global.rtc_peer = null
	Global.rtc_conn = null
	multiplayer.multiplayer_peer = null
	# Keep this scene alive until the click release has finished; otherwise it can open Settings on the new menu.
	await get_tree().create_timer(0.12, true).timeout
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
'''
	_write_replacement(path, source, old, new)

func _patch_pause_menu() -> void:
	var path := "res://scripts/ui/menus/pause/pause_menu.gd"
	var source := FileAccess.get_file_as_string(path)
	if not source.contains("var returning_to_main_menu := false"):
		source = source.replace("@onready var main_menu_button: Button = $Panel/VBoxContainer/ButtonMainMenu\n", "@onready var main_menu_button: Button = $Panel/VBoxContainer/ButtonMainMenu\n\nvar returning_to_main_menu := false\n")
	var old := '''func _on_button_main_menu_pressed() -> void:
	get_tree().paused = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
'''
	var new := '''func _on_button_main_menu_pressed() -> void:
	if returning_to_main_menu:
		return
	returning_to_main_menu = true
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	# Keep the pause panel alive through mouse release before loading the clickable main menu.
	await get_tree().create_timer(0.12, true).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
'''
	_write_replacement(path, source, old, new)

func _patch_bestiary() -> void:
	var path := "res://scripts/ui/menus/lexicon/lexikon.gd"
	var source := FileAccess.get_file_as_string(path)
	if not source.contains("var returning_to_menu := false"):
		source = source.replace("]\n\nfunc _ready() -> void:", "]\n\nvar returning_to_menu := false\n\nfunc _ready() -> void:")
	var old := '''func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
'''
	var new := '''func _on_back_pressed() -> void:
	if returning_to_menu:
		return
	returning_to_menu = true
	await get_tree().create_timer(0.12, true).timeout
	get_tree().change_scene_to_file("res://scenes/menus/main/menu.tscn")
'''
	_write_replacement(path, source, old, new)

func _write_replacement(path: String, source: String, old_text: String, new_text: String) -> void:
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Missing transition target in %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
