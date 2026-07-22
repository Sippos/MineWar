extends SceneTree
func _init():
    var source = TileSetAtlasSource.new()
    source.texture_region_size = Vector2i(128, 128)
    source.create_tile(Vector2i(0, 0))
    var td = source.get_tile_data(Vector2i(0, 0), 0)
    print("Default texture origin: ", td.texture_origin)
    quit()
