extends SceneTree

func _init():
	var world = load("res://scripts/systems/world_generation/world.gd").new()
	world.player_id = 1
	var a = AStarGrid2D.new()
	a.region = Rect2i(-30, -5, 60, 60)
	a.cell_size = Vector2(64, 64)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	a.update()

	# Simulate world blocks (all solid below surface)
	for x in range(-20, 20):
		for y in range(0, 30):
			if a.is_in_bounds(x, y):
				a.set_point_solid(Vector2i(x, y), true)
	
	# Open surface
	for x in range(-20, 20):
		var cell = Vector2i(x, -1)
		if a.is_in_bounds(cell.x, cell.y):
			a.set_point_solid(cell, false)
			
	# Base clearing
	for x in range(-2, 3):
		for y in range(0, 2):
			if a.is_in_bounds(x, y):
				a.set_point_solid(Vector2i(x, y), false)
	
	# Dig a tunnel (e.g. from x=0 down to y=5, then right to x=5)
	for y in range(2, 6):
		a.set_point_solid(Vector2i(0, y), false)
	for x in range(1, 6):
		a.set_point_solid(Vector2i(x, 5), false)

	# Farthest open cell should be (5, 5)
	var path = a.get_id_path(Vector2i(5, 5), Vector2i(0, -1))
	print("Path from (5,5) to (0,-1): ", path)
	quit()
