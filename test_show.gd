extends SceneTree
func _init():
    var level = preload("res://scenes/world/mine/level.tscn").instantiate()
    root.add_child(level)
    await create_timer(0.1).timeout
    var menu = level.get_node("UpgradeMenu")
    var base = level.get_node("Base")
    base.player_in_zone = true
    base.upgrade_requested.emit()
    await create_timer(0.1).timeout
    if menu.get_node("Panel").visible:
        print("MENU SUCCESSFULLY OPENED!")
    else:
        print("MENU FAILED TO OPEN!")
    quit()
