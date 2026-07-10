extends SceneTree

func _init():
    print("Starting test...")
    var scene = load("res://scenes/menus/lexicon/lexikon.tscn")
    if scene == null:
        print("FAILED TO LOAD SCENE")
    else:
        var instance = scene.instantiate()
        print("Scene instantiated successfully.")
        
        # Test back button signal
        var btn = instance.get_node("VBoxContainer/TopBar/BackButton")
        if btn.pressed.is_connected(instance._on_back_pressed):
            print("Back button is connected!")
        else:
            print("Back button NOT CONNECTED")
            
    quit()
