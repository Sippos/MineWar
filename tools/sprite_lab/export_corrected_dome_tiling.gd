extends Node

const WORKBENCH_SCENE := preload("res://tools/sprite_lab/dome_material_workbench.tscn")

func _ready() -> void:
	var workbench: Node = WORKBENCH_SCENE.instantiate()
	add_child(workbench)
	await get_tree().process_frame
	workbench.call("_export_runtime_assets")
	await get_tree().process_frame
	var logs: String = ""
	var status: Label = workbench.get("status_label") as Label
	if status != null:
		logs = status.text
	print("Dome export status: ", logs)
	get_tree().quit()
