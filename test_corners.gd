extends SceneTree

func _init():
    var packed = load("res://scenes/world/mine/level.tscn")
    var level = packed.instantiate()
    var tile_set = level.get_node("BlockLayer").tile_set
    print("TileSet loaded: ", tile_set != null)
    
    var path = "res://assets/sprites/world/terrain/dome/Easy_Inside_Corners_CLEAN.png"
    var tex = load(path)
    if tex == null:
        print("Failed to load ", path)
        quit()
        return
        
    var image
    if tex is Texture2D:
        image = tex.get_image()
    print("Image loaded: ", image != null)
    
    var img_tex = ImageTexture.create_from_image(image)
    print("Image width: ", img_tex.get_width())
    
    quit()
