extends Node

var failures: Array[String] = []

func _ready() -> void:
	_patch_settings()
	_patch_controls()
	_patch_multiplayer_menu()
	_patch_hero_selection()
	if failures.is_empty():
		print("FIX_MODAL_CLICKTHROUGH_PATCH_OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _patch_settings() -> void:
	var path := "res://scripts/ui/menus/settings_menu.gd"
	_replace_once(path, "var _loading := false\n", "var _loading := false\nvar _closing := false\n")
	_replace_once(path, "\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\ttheme = MENU_THEME", "\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\tz_index = 100\n\ttheme = MENU_THEME")
	_replace_once(path, "func _on_back_pressed() -> void:\n\tqueue_free()\n", "func _on_back_pressed() -> void:\n\tif _closing:\n\t\treturn\n\t_closing = true\n\tback_button.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)\n")

func _patch_controls() -> void:
	var path := "res://scripts/ui/menus/controls/controls_menu.gd"
	_replace_once(path, "extends CanvasLayer\n", "extends CanvasLayer\n\nvar _closing := false\n")
	_replace_once(path, "func _on_back_pressed() -> void:\n\tqueue_free()\n", "func _on_back_pressed() -> void:\n\tif _closing:\n\t\treturn\n\t_closing = true\n\t$Panel/VBoxContainer/BackButton.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)\n")

func _patch_multiplayer_menu() -> void:
	var path := "res://scripts/ui/menus/multiplayer_menu.gd"
	_replace_once(path, "var online_mode := false\n", "var online_mode := false\nvar closing := false\n")
	_replace_once(path, "\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\ttheme = MENU_THEME", "\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\tz_index = 100\n\ttheme = MENU_THEME")
	_replace_once(path, "func _on_back_pressed() -> void:\n\tqueue_free()\n", "func _on_back_pressed() -> void:\n\tif closing:\n\t\treturn\n\tclosing = true\n\tback_button.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)\n")

func _patch_hero_selection() -> void:
	var path := "res://hero_selection_menu.gd"
	_replace_once(path, "var ability_icon_cache = {}\n", "var ability_icon_cache = {}\nvar closing := false\n")
	_replace_once(path, "func _ready() -> void:\n\tp1_prev.pressed.connect", "func _ready() -> void:\n\tz_index = 100\n\tp1_prev.pressed.connect")
	_replace_once(path, "func _on_back_pressed() -> void:\n\tqueue_free()\n", "func _on_back_pressed() -> void:\n\tif closing:\n\t\treturn\n\tclosing = true\n\tback_btn.disabled = true\n\tstart_btn.disabled = true\n\tget_tree().create_timer(0.06, true).timeout.connect(queue_free)\n")

func _replace_once(path: String, old_text: String, new_text: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		failures.append("Could not read %s" % path)
		return
	if source.contains(new_text):
		return
	if not source.contains(old_text):
		failures.append("Missing target in %s: %s" % [path, old_text.left(100)])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(source.replace(old_text, new_text))
	file.close()
