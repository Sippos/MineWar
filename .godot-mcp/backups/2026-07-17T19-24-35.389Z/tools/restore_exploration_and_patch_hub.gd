extends Node

const EXPLORATION_BACKUP := "res://.godot-mcp/backups/2026-07-17T17-47-22.429Z/scripts/systems/world_generation/exploration_mode_controller.gd"
const EXPLORATION_TARGET := "res://scripts/systems/world_generation/exploration_mode_controller.gd"
const HUB_CONTROLLER := "res://scripts/systems/preparation/preparation_world_controller.gd"
const PROJECT_FILE := "res://project.godot"

func _ready() -> void:
	_restore_exploration()
	_patch_hub()
	_patch_project()
	print("MINEWARS_HUB_PATCH_OK")
	get_tree().quit()

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	