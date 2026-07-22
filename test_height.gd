extends SceneTree
func _init():
    var source = TileSetAtlasSource.new()
    source.texture = load("res://assets/sprites/world/terrain/dome/Easy_Front_Face.png")
    source.texture_region_size = Vector2i(64, 26)
    source.create_tile(Vector2i(0, 0))
    var td = source.get_tile_data(Vector2i(0, 0), 0)
    td.texture_origin = Vector2i(0, 19)
    print("Texture origin is: ", td.texture_origin)
    quit()
