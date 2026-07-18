extends Node

func _ready() -> void:
	var path := "res://scripts/systems/single_player_world_controller.gd"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("hub_camera.zoom = Vector2.ONE", "hub_camera.zoom = Vector2(0.82, 0.82)")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	get_tree().quit()
