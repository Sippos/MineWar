extends SceneTree
func _init():
    var scene = load("res://scenes/world/mine/level.tscn")
    if scene == null:
        print("ERROR: Could not load scene!")
    else:
        print("Scene loaded successfully!")
    quit()
