extends Node

func _ready() -> void:
	_patch_controller()
	_patch_test()
	print("FIRST_EXPLORATION_CHAMBER_PATCHED")
	get_tree().quit()

func _patch_controller() -> void:
	var path := "res://scripts/systems/world_generation/exploration_mode_controller.gd"
	var source := FileAccess.get_file_as_string(path)
	var old := "const FIRST_NEST_CELL := Vector2i(-4, 6)"
	var replacement := "const FIRST_NEST_CELL := Vector2i(0, 6)"
	assert(source.contains(old), "Expected first nest constant was not found")
	source = source.replace(old, replacement)
	var file