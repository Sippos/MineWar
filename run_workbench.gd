@tool
extends SceneTree

func _initialize() -> void:
	var ScriptClass = load("res://tools/sprite_lab/dome_material_workbench.gd")
	var instance = ScriptClass.new()
	if instance.has_method("_load_images"):
		instance._load_images()
	if instance.has_method("_export_all"):
		instance._export_all()
	print("Exported all images.")
	quit()
