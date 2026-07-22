extends Node

func _ready() -> void:
	var path := "res://hero_selection_menu.gd"
	var source := FileAccess.get_file_as_string(path)
	var old_text := "func _apply_context_labels() -> void:\n\tif current_mode == Mode.SINGLE_PLAYER:\n\t\ttitle_label.text = \"Choose Hero & Matching Base\" if current_context == \"solo_retry\" else \"Select Hero & Matching Base\"\n\t\tp1_player_caption.text = \"HERO\"\n\telse:\n\t\ttitle_label.text = \"Select Heroes\"\n\t\tp1_player_caption.text = \"PLAYER 1\"\n\tp2_player_caption.text = \"PLAYER 2\"\n\tstart_btn.text = \"Retry from Surface\" if current_context == \"solo_retry\" else \"Start\"\n"
	var new_text := "func _apply_context_labels() -> void:\n\tif current_mode == Mode.SINGLE_PLAYER:\n\t\ttitle_label.text = \"Choose Hero & Matching Base\" if current_context == \"solo_retry\" else \"Select Hero & Matching Base\"\n\t\tp1_player_caption.text = \"HERO\"\n\telif current_mode == Mode.VS_ONLINE:\n\t\ttitle_label.text = \"CHOOSE ONLINE HERO\"\n\t\tp1_player_caption.text = \"HERO\"\n\telse:\n\t\ttitle_label.text = \"SELECT LOCAL HEROES\"\n\t\tp1_player_caption.text = \"PLAYER 1\"\n\tp2_player_caption.text = \"PLAYER 2\"\n\tstart_btn.text = \"Retry from Surface\" if current_context == \"solo_retry\" else (\"Continue to Room Code\" if current_mode == Mode.VS_ONLINE else \"Start\")\n"
	if source.contains(new_text):
		print("FINAL_MENU_WORDING_PATCH_ALREADY_APPLIED")
		get_tree().quit(0)
		return
	if source.is_empty() or not source.contains(old_text):
		push_error("Hero selection wording patch target missing")
		get_tree().quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write hero_selection_menu.gd")
		get_tree().quit(1)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
	print("FINAL_MENU_WORDING_PATCH_OK")
	get_tree().quit(0)
