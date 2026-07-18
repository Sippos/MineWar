extends Node

func _ready() -> void:
	_patch_world()
	_patch_controller()
	print("MINEWARS_OBJECTIVE_EVENTS_FIXED")
	get_tree().quit()

func _patch_world() -> void:
	var path := "res://scripts/systems/world_generation/world.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read world.gd")
		return
	var source := file.get_as_text()
	file.close()
	var old := "func notify_tutorial_cell_dug(_cell: Vector2i, contained_gem: bool) -> void:\n\tif not onboarding