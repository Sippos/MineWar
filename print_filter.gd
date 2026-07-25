@tool
extends SceneTree
func _initialize():
    print("NEAREST = ", CanvasItem.TEXTURE_FILTER_NEAREST)
    print("LINEAR = ", CanvasItem.TEXTURE_FILTER_LINEAR)
    quit()
