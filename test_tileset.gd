extends SceneTree
func _init():
    var ts = ResourceLoader.load("res://scenes/boot/main.tscn")
    print("Loaded scene")
    quit()
