extends SceneTree

func _init():
    var vs_scene = load("res://vs_mode.tscn").instantiate()
    var root = Window.new()
    root.add_child(vs_scene)
    
    await create_timer(0.5).timeout
    
    var level1 = vs_scene.get_node("HBoxContainer/SubViewportContainer1/SubViewport1/Level1")
    var level2 = vs_scene.get_node("HBoxContainer/SubViewportContainer2/SubViewport2/Level2")
    var hud1 = level1.get_node("HUD")
    var upg_menu1 = level1.get_node("UpgradeMenu")
    
    print("Level2 enemy count before: ", level2.get_node("BlockLayer").get_child_count()) # Wait, enemies are children of level2!
    
    hud1.add_gems(100)
    
    upg_menu1.show_menu()
    
    # Wait for panels to populate
    await create_timer(0.1).timeout
    
    # Simulate clicking "Send Enemies" from VS Prompt
    # Wait, the button for Send Enemies is created dynamically in _create_vs_panels
    # Let's just call _on_vs_send_pressed() directly
    upg_menu1._on_vs_send_pressed()
    
    await create_timer(0.1).timeout
    
    # Find the Rat button and emit its pressed signal
    var vbox = upg_menu1.vs_send_panel.get_child(0)
    var rat_btn = vbox.get_child(1) # lbl2 is index 0
    rat_btn.pressed.emit()
    
    await create_timer(0.5).timeout
    
    var enemies = 0
    for child in level2.get_children():
        if "enemy_type" in child:
            enemies += 1
            print("Found enemy: ", child.enemy_type)
            
    print("Level2 new enemy count: ", enemies)
    
    print("Test3 finished")
    quit()
