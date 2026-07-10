extends Node

func _ready() -> void:
	print("Starting Godot headless test...")
	var instance = load("res://scenes/menus/lexicon/lexikon.tscn").instantiate()
	add_child(instance)
	print("Scene instantiated successfully.")
	get_tree().quit()
