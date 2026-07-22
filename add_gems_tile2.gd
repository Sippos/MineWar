extends SceneTree
func _init():
    var scene = ResourceLoader.load("res://scenes/world/mine/level.tscn")
    var node = scene.instantiate()
    var block_layer = node.get_node("BlockLayer")
    var tileset = block_layer.tile_set

    # Clean up previous failed attempts if they exist
    if tileset.has_source(18):
        tileset.remove_source(18)
    if tileset.has_source(19):
        tileset.remove_source(19)
    if tileset.has_source(20):
        tileset.remove_source(20)

    # Note: adding collision polygon failed because the tile doesn't have a physics layer yet.
    # Actually, the physics layer exists on the TileSet!
    # But we need to use the correct API. `tileset.get_physics_layers_count()` should be 1.

    # Create Gems source (19)
    var gems_tex = load("res://assets/sprites/world/terrain/bricks/Gems_Brick.png")
    var gems_source = TileSetAtlasSource.new()
    gems_source.texture = gems_tex
    gems_source.texture_region_size = Vector2i(64, 64)
    gems_source.create_tile(Vector2i(0, 0))
    # Physics layer 0
    var polygon = PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])
    # According to Godot 4 API, tile_data.add_collision_polygon is correct. 
    # But wait, it failed with "Index p_layer_id = 0 is out of bounds (physics.size() = 0)."
    # That means the TileSetAtlasSource itself doesn't know about the TileSet's physics layer until it's added to the TileSet!
    tileset.add_source(gems_source, 19)
    # NOW we can add collision!
    gems_source.get_tile_data(Vector2i(0, 0), 0).add_collision_polygon(0)
    gems_source.get_tile_data(Vector2i(0, 0), 0).set_collision_polygon_points(0, 0, polygon)

    # Create Edge Gems source (20)
    var edge_gems_tex = load("res://assets/sprites/world/terrain/dome/Gems_Border_Atlas.png")
    var edge_gems_source = TileSetAtlasSource.new()
    edge_gems_source.texture = edge_gems_tex
    edge_gems_source.texture_region_size = Vector2i(64, 64)
    tileset.add_source(edge_gems_source, 20)
    for y in range(4):
        for x in range(4):
            edge_gems_source.create_tile(Vector2i(x, y))

    # Save
    var packed = PackedScene.new()
    packed.pack(node)
    ResourceSaver.save(packed, "res://scenes/world/mine/level.tscn")
    print("Done adding tileset sources properly")
    quit()
