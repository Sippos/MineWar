extends SceneTree

func _init():
    var a = AStarGrid2D.new()
    a.region = Rect2i(0, -5, 20, 20)
    a.cell_size = Vector2(64, 64)
    a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    a.update()

    # Make everything solid initially
    for x in range(20):
        for y in range(-5, 15):
            a.set_point_solid(Vector2i(x, y), true)

    # Base at (0, -1)
    a.set_point_solid(Vector2i(0, -1), false)
    a.set_point_solid(Vector2i(0, 0), false)
    
    # Vertical shaft at x=0 from y=0 to y=7
    for y in range(0, 8):
        a.set_point_solid(Vector2i(0, y), false)
        
    # Horizontal tunnel from x=0 to x=15 at y=5,6,7
    for x in range(1, 16):
        a.set_point_solid(Vector2i(x, 5), false)
        a.set_point_solid(Vector2i(x, 6), false)
        a.set_point_solid(Vector2i(x, 7), false)

    # Set weights based on my world.gd logic
    for x in range(20):
        for y in range(-5, 15):
            if a.is_in_bounds(x, y) and not a.is_point_solid(Vector2i(x, y)):
                var is_grounded = a.is_point_solid(Vector2i(x, y + 1))
                if is_grounded:
                    a.set_point_weight_scale(Vector2i(x, y), 1.0)
                else:
                    a.set_point_weight_scale(Vector2i(x, y), 50.0)

    # Path from (15, 5) (ceiling) to (0, -1)
    var p = a.get_id_path(Vector2i(15, 5), Vector2i(0, -1))
    print("Path from 15,5: ", p)
    
    # Path from (15, 7) (floor) to (0, -1)
    var p2 = a.get_id_path(Vector2i(15, 7), Vector2i(0, -1))
    print("Path from 15,7: ", p2)

    quit()
