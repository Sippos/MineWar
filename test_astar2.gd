extends SceneTree

func _init():
    var a = AStarGrid2D.new()
    a.region = Rect2i(0, 0, 10, 10)
    a.cell_size = Vector2(64, 64)
    a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    a.update()
    
    # 3-high tunnel: floor is y=7, middle y=6, top y=5
    # y=4 and y=8 are solid
    for x in range(10):
        a.set_point_solid(Vector2i(x, 4), true)
        a.set_point_solid(Vector2i(x, 8), true)
        
        # weights
        a.set_point_weight_scale(Vector2i(x, 7), 1.0) # floor
        a.set_point_weight_scale(Vector2i(x, 6), 50.0) # middle
        a.set_point_weight_scale(Vector2i(x, 5), 50.0) # top
        
    # Start at top right (9, 5). Target base at top left (0, 0)
    # wait, target base is at y=0, but y=0..3 are empty (weight 50.0).
    for x in range(10):
        for y in range(0, 4):
            a.set_point_weight_scale(Vector2i(x, y), 50.0)
            
    # Path from (9, 5) to (0, 0)
    # Wait, there's a solid wall at y=4, so it can't reach y=0!
    # Let's make a vertical shaft at x=0
    for y in range(0, 9):
        a.set_point_solid(Vector2i(0, y), false)
        if y < 8:
            a.set_point_weight_scale(Vector2i(0, y), 50.0)
            
    var p = a.get_id_path(Vector2i(9, 5), Vector2i(0, 0))
    print("Path: ", p)
    quit()
