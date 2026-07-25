extends SceneTree

func _init():
    var packed = load("res://scenes/world/preparation/preparation_hub.tscn")
    var hub = packed.instantiate()
    var level = hub.get_node("Level")
    print("Level is: ", level)
    print("Does Level have InsideCornerTL? ", level.has_node("InsideCornerTL"))
    print("Children of Level: ")
    for c in level.get_children():
        print(c.name)
    quit()
