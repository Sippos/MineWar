extends Node

func _ready() -> void:
	var path := "res://hero_balance_controller.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("var can_replace_health :=", "var can_replace_health: bool =")
	text = text.replace("var can_replace_speed :=", "var can_replace_speed: bool =")
	text = text.replace("var can_replace_dig :=", "var can_replace_dig: bool =")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("HERO_BALANCE_TYPE_FIX_APPLIED")
	get_tree().quit()
