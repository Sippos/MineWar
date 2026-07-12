extends SceneTree

func _init():
    var world = load("res://scripts/systems/world_generation/world.gd").new()
    # It has astar but relies on child nodes like BlockLayer, so we need a minimal setup
    # Actually let's just make an AStarGrid2D and check Godot's behavior
    var a = AStarGrid2D.new()
    a.region = Rect2i(0, 0, 10, 10)
    a.cell_size = Vector2(64, 64)
    a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    a.update()
    
    # Simulate my weight setup
    a.set_point_weight_scale(Vector2i(5, 5), 50.0) # Floating
    a.set_point_weight_scale(Vector2i(6, 5), 50.0)
    a.set_point_weight_scale(Vector2i(7, 5), 50.0)
    
    a.set_point_weight_scale(Vector2i(5, 7), 1.0) # Floor
    a.set_point_weight_scale(Vector2i(6, 7), 1.0)
    a.set_point_weight_scale(Vector2i(7, 7), 1.0)
    
    # Path from (7, 5) to (0, 5)
    var p = a.get_id_path(Vector2i(7, 5), Vector2i(0, 5))
    print("Path: ", p)
    quit()
