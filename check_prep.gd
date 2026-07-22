extends SceneTree
func _init():
    var script = load("res://scripts/systems/preparation/preparation_fast_world.gd")
    if script == null:
        print("ERROR: Could not load script!")
    else:
        print("Script loaded successfully!")
    quit()
