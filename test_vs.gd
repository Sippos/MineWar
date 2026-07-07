extends SceneTree
func _init():
    var vs_scene = load("res://vs_mode.tscn").instantiate()
    var root = Window.new()
    root.add_child(vs_scene)
    
    # Wait one frame for _ready
    await create_timer(0.1).timeout
    
    var level1 = vs_scene.get_node("HBoxContainer/SubViewportContainer1/SubViewport1/Level1")
    var hud1 = level1.get_node("HUD")
    var upg_menu1 = level1.get_node("UpgradeMenu")
    
    hud1.add_gems(100)
    print("Gems: ", hud1.total_gems)
    
    upg_menu1.show_menu()
    upg_menu1._on_send_rat()
    
    await create_timer(0.1).timeout
    print("Test finished")
    quit()
