extends SceneTree
func _init():
	var wb = preload("res://tools/sprite_lab/dome_material_workbench.gd").new()
	wb._load_images()
	wb._export_runtime_assets()
	print("Export completed successfully.")
	quit(0)
