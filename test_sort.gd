extends SceneTree
func _init():
    var layer = TileMapLayer.new()
    if "y_sort_origin" in layer:
        print("HAS y_sort_origin: " + str(layer.y_sort_origin))
    else:
        print("NO y_sort_origin on TileMapLayer")
    quit()
