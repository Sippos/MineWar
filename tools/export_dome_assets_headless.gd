extends SceneTree
func _init():
    var bench = load("res://tools/sprite_lab/dome_material_workbench.gd").new()
    bench._ready()
    bench._export_runtime_assets()
    print("Done exporting")
    quit()
