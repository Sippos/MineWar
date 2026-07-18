extends Node

func _ready() -> void:
	var path := "res://scripts/systems/preparation/in_world_hero_selector.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("card.scale = Vector2(0.50, 0.50)", "card.scale = Vector2(0.66, 0.66)")
	text = text.replace("Vector2(0.56, 0.56)", "Vector2(0.72, 0.72)")
	text = text.replace("Vector2(0.52, 0.52)", "Vector2(0.68, 0.68)")
	text = text.replace("func _update_card_position() -> void:\n\tif card == null", "func _update_card_position() -> void:\n\tif card != null:\n\t\tcard.size = CARD_SIZE\n\tif card == null")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	get_tree().quit()
