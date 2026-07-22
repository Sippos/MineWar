extends SceneTree
func _init():
	var packed = ResourceLoader.load("res://tools/sprite_lab/dome_material_workbench.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene._export_runtime_assets()
	print("Export done")
	quit()
