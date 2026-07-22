extends SceneTree

func _init():
    var level = load("res://scenes/world/mine/level.tscn").instantiate()
    var root = Node.new()
    root.add_child(level)
    
    level._install_runtime_terrain_textures()
    
    var ts = level.block_layer.tile_set
    var source_10 = ts.get_source(10)
    if source_10:
        print("Source 10 exists, texture: ", source_10.texture.resource_path)
    else:
        print("Source 10 MISSING!")
        
    level.block_layer.set_cell(Vector2i(0, -1), 1, Vector2i.ZERO) # Easy rock
    level.block_layer.set_cell(Vector2i(0, 0), -1, Vector2i.ZERO) # Empty below
    level.update_front_wall(Vector2i(0, -1))
    
    print("Front layer cell at 0,0: ", level.front_layer.get_cell_source_id(Vector2i(0, 0)))
    
    quit()
