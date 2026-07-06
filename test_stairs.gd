extends SceneTree

func _init():
    var a = AStarGrid2D.new()
    a.region = Rect2i(0, 0, 10, 10)
    a.cell_size = Vector2(64, 64)
    a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    a.update()

    # Fill solid
    for x in range(10):
        for y in range(10):
            a.set_point_solid(Vector2i(x, y), true)

    # Dig a 1-wide staircase
    for i in range(10):
        a.set_point_solid(Vector2i(i, i), false)

    var p = a.get_id_path(Vector2i(9, 9), Vector2i(0, 0))
    print("Path for 1-wide: ", p)
    
    # Dig a 2-wide staircase
    for i in range(9):
        a.set_point_solid(Vector2i(i, i+1), false)
        
    var p2 = a.get_id_path(Vector2i(9, 9), Vector2i(0, 0))
    print("Path for 2-wide: ", p2)

    quit()
