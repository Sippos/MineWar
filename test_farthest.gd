extends SceneTree

func _init():
    var astar = AStarGrid2D.new()
    astar.region = Rect2i(-30, -40, 60, 85)
    astar.cell_size = Vector2(64, 64)
    astar.update()
    
    # Fill solid
    for x in range(-20, 20):
        for y in range(-35, 30):
            astar.set_point_solid(Vector2i(x,y), true)
            
    # Dig base pocket
    for x in range(-5, 6):
        for y in range(-4, 0):
            astar.set_point_solid(Vector2i(x,y), false)
            
    var start_cell = Vector2i(0, -1)
    var queue = [start_cell]
    var visited = {start_cell: 0}
    var farthest_cell = start_cell
    var max_dist = 0

    var min_y = -35
    var max_y = -1

    while queue.size() > 0:
        var curr = queue.pop_front()
        var dist = visited[curr]

        if curr.y >= min_y and curr.y <= max_y and curr.x >= -20 and curr.x < 20:
            if dist > max_dist:
                max_dist = dist
                farthest_cell = curr
            
        var neighbors = [
            Vector2i(curr.x + 1, curr.y),
            Vector2i(curr.x - 1, curr.y),
            Vector2i(curr.x, curr.y + 1),
            Vector2i(curr.x, curr.y - 1)
        ]
        
        for n in neighbors:
            if n.x >= -20 and n.x < 20 and n.y >= -35 and n.y < 30:
                if not astar.is_point_solid(n) and not visited.has(n):
                    visited[n] = dist + 1
                    queue.append(n)
                    
    print("FARTHEST CELL WITHOUT DIGGING: ", farthest_cell)
    
    # Dig up to -10
    for y in range(-5, -11, -1):
        astar.set_point_solid(Vector2i(0, y), false)
        
    queue = [start_cell]
    visited = {start_cell: 0}
    farthest_cell = start_cell
    max_dist = 0
    while queue.size() > 0:
        var curr = queue.pop_front()
        var dist = visited[curr]

        if curr.y >= min_y and curr.y <= max_y and curr.x >= -20 and curr.x < 20:
            if dist > max_dist:
                max_dist = dist
                farthest_cell = curr
            
        var neighbors = [
            Vector2i(curr.x + 1, curr.y),
            Vector2i(curr.x - 1, curr.y),
            Vector2i(curr.x, curr.y + 1),
            Vector2i(curr.x, curr.y - 1)
        ]
        
        for n in neighbors:
            if n.x >= -20 and n.x < 20 and n.y >= -35 and n.y < 30:
                if not astar.is_point_solid(n) and not visited.has(n):
                    visited[n] = dist + 1
                    queue.append(n)
                    
    print("FARTHEST CELL WITH DIGGING TO -10: ", farthest_cell)
    quit()
