extends SceneTree

func _init():
    var level = load("res://scenes/world/mine/level.tscn").instantiate()
    var root = Node.new()
    root.add_child(level)
    level._ready()
    print("Level initialized!")
    
    # Check if FrontWallLayer exists and is visible
    var front = level.get_node("FrontWallLayer")
    if front.visible:
        print("FrontWallLayer is visible")
    else:
        print("FrontWallLayer is hidden")
        
    # Check if InsideCornerTL exists
    var inside = level.get_node("InsideCornerTL")
    if inside:
        print("InsideCornerTL exists")
    
    quit()
