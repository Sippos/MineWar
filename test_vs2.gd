extends SceneTree
func _init():
    var level1 = load("res://level.tscn").instantiate()
    var root = Window.new()
    root.add_child(level1)
    
    var upg = level1.get_node("UpgradeMenu")
    upg.add_user_signal("send_enemy")
    upg.connect("send_enemy", Callable(self, "_on_p1_send_enemy"))
    
    await create_timer(0.1).timeout
    
    var hud1 = level1.get_node("HUD")
    hud1.add_gems(100)
    
    upg.show_menu()
    upg._on_send_rat()
    
    await create_timer(0.1).timeout
    print("Test2 finished")
    quit()

func _on_p1_send_enemy(enemy_type: int) -> void:
    print("p1 sending enemy type ", enemy_type)
