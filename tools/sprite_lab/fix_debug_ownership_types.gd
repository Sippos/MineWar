extends Node

const PATH := "res://tools/sprite_lab/debug_extrusion_source_ownership.gd"

func _ready() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	text = text.replace("var face_y :=", "var face_y: int =")
	text = text.replace("var wy :=", "var wy: int =")
	text = text.replace("var wx :=", "var wx: int =")
	text = text.replace("var sy :=", "var sy: int =")
	text = text.replace("var idx :=", "var idx: int =")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	get_tree().quit()