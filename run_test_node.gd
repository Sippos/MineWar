extends Node

func _ready() -> void:
	print("Starting Godot headless test...")
	var instance = load("res://lexikon.tscn").instantiate()
	add_child(instance)
	print("Scene instantiated successfully.")
	get_tree().quit()
