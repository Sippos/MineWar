extends Node

func _ready() -> void:
	var prep_script = load("res://scripts/systems/preparation/preparation_fast_world.gd")
	var gem_script = load("res://scripts/systems/world_generation/world_gem_visuals.gd")
	var level_scene = load("res://scenes/world/mine/level.tscn")
	print("GEM_SCRIPT_VALIDATE prep=", prep_script != null, " gem=", gem_script != null, " level=", level_scene != null)
	get_tree().quit()
