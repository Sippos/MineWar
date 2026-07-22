extends Node

const FONT_LINE := "const MENU_FONT: FontFile = preload(\"res://assets/fonts/cinzel/Cinzel-Variable.ttf\")"

func _ready() -> void:
	_fix("res://scripts/ui/menus/controls/controls_menu.gd")
	_fix("res://scripts/ui/menus/settings_menu.gd")
	print("MENU_FONT_RESTORED")
	get_tree().quit()

func _fix(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if not text.contains("const MENU_FONT"):
		var first_end := text.find("\n")
		text = text.substr(0, first_end + 1) + "\n" + FONT_LINE + "\n" + text.substr(first_end + 1)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
