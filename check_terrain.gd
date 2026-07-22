extends SceneTree
func _init():
    var script = load("res://scripts/systems/world_generation/world_terrain_runtime.gd")
    if script == null:
        print("ERROR: Could not load script!")
    else:
        print("Script loaded successfully!")
    quit()
