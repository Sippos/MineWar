extends Node

const WORKBENCH := preload("res://tools/sprite_lab/dome_material_workbench.gd")
const PREVIEW := preload("res://tools/sprite_lab/dome_material_preview_v2.gd")
const CANVAS := preload("res://tools/sprite_lab/dome_material_canvas.gd")
const RUNTIME_FRONT := preload("res://scripts/systems/world_generation/dome_front_extrusion_renderer.gd")

func _ready() -> void:
	var workbench := WORKBENCH.new()
	var preview := PREVIEW.new()
	var canvas := CANVAS.new()
	var runtime_front := RUNTIME_FRONT.new()
	if workbench == null or preview == null or canvas == null or runtime_front == null:
		push_error("Could not instantiate patched scripts")
		get_tree().quit(1)
		return
	print("Overscan/front-face patch scripts parse and instantiate successfully.")
	get_tree().quit()
