extends Node

func _ready() -> void:
	var scene := load("res://tools/sprite_lab/dome_material_workbench.tscn") as PackedScene
	if scene == null:
		push_error("Could not load Dome Border Workbench")
		get_tree().quit(1)
		return
	var workbench := scene.instantiate()
	add_child(workbench)
	await get_tree().process_frame
	workbench.call("_export_runtime_assets")
	await get_tree().process_frame
	print("Exported Dome mass, borders and inside-corner atlases")
	get_tree().quit()
