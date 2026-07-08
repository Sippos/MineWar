extends SceneTree
func _init():
    var menu = load("res://menu.tscn").instantiate()
    root.add_child(menu)
    print("Menu instantiated successfully")
    await create_timer(0.1).timeout
    quit()
