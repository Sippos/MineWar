extends SceneTree
func _init():
    var scene = ResourceLoader.load("res://scenes/world/mine/level.tscn")
    var node = scene.instantiate()
    var block_layer = node.get_node("BlockLayer")
    var tileset = block_layer.tile_set

    # Create Gems source
    var gems_tex = load("res://assets/sprites/world/terrain/bricks/Gems_Brick.png")
    var gems_source = TileSetAtlasSource.new()
    gems_source.texture = gems_tex
    gems_source.texture_region_size = Vector2i(64, 64)
    gems_source.create_tile(Vector2i(0, 0))
    # Physics layer 0
    var polygon = PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])
    gems_source.get_tile_data(Vector2i(0, 0), 0).add_collision_polygon(0)
    gems_source.get_tile_data(Vector2i(0, 0), 0).set_collision_polygon_points(0, 0, polygon)
    tileset.add_source(gems_source, 4)

    # Create Edge Gems source
    var edge_gems_tex = load("res://assets/sprites/world/terrain/dome/Gems_Border_Atlas.png")
    var edge_gems_source = TileSetAtlasSource.new()
    edge_gems_source.texture = edge_gems_tex
    edge_gems_source.texture_region_size = Vector2i(64, 64)
    for y in range(4):
        for x in range(4):
            edge_gems_source.create_tile(Vector2i(x, y))
    tileset.add_source(edge_gems_source, 18)

    # Save
    var packed = PackedScene.new()
    packed.pack(node)
    ResourceSaver.save(packed, "res://scenes/world/mine/level.tscn")
    print("Done adding tileset sources")
    quit()
