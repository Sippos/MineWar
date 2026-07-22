extends SceneTree

func _init():
    var bench = load("res://tools/sprite_lab/dome_material_workbench.gd").new()
    bench.current_tier = "unmineable"
    bench._load_images()
    bench._export_fronts()
    print("Exported unmineable front face!")
    quit()
