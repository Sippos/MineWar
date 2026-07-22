extends Node

func _ready() -> void:
	var directories: Array[String] = [
		"res://tools/sprite_lab",
		"res://tools/sprite_lab/recipes",
		"res://tools/sprite_lab/stamps",
		"res://assets/sprites/world/terrain/generated_sprite_lab",
		"res://assets/sprites/world/terrain/generated_sprite_lab/golden_v2"
	]
	for directory: String in directories:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	print("SPRITE_LAB_DIRECTORIES_READY")
	get_tree().quit(0)
