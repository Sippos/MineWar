import re

with open("world.gd", "r") as f:
    content = f.read()

# Replace on_cell_dug completely
old_dug_section = """func on_cell_dug(cell: Vector2i) -> void:
	if astar.is_in_bounds(cell.x, cell.y):
		astar.set_point_solid(cell, false)
	
	block_layer.erase_cell(cell)
	damage_layer.erase_cell(cell)
	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	bg_layer.erase_cell(cell) # Just in case
	
	update_neighbors(cell)

func update_neighbors(cell: Vector2i) -> void:
	var neighbors = [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]
	
	for n in neighbors:
		var block_id = block_layer.get_cell_source_id(n)
		if block_id != -1:
			# Change fog to the transparent border mask (Source 0)
			# This reveals the edges of the block underneath but keeps the center black
			fog_layer.set_cell(n, 0, Vector2i(0, 0))
			
			# Remove edge overlay as we don't need it anymore
			edge_layer.erase_cell(n)"""

new_dug_section = """func on_cell_dug(cell: Vector2i) -> void:
	if astar.is_in_bounds(cell.x, cell.y):
		astar.set_point_solid(cell, false)
	
	block_layer.erase_cell(cell)
	damage_layer.erase_cell(cell)
	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	bg_layer.erase_cell(cell)
	
	update_fog_mask(cell) # Clean up this cell
	
	var neighbors = [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]
	
	for n in neighbors:
		update_fog_mask(n)

func update_fog_mask(cell: Vector2i) -> void:
	if block_layer.get_cell_source_id(cell) == -1:
		fog_layer.erase_cell(cell)
		return
		
	var top_open = block_layer.get_cell_source_id(Vector2i(cell.x, cell.y - 1)) == -1
	var right_open = block_layer.get_cell_source_id(Vector2i(cell.x + 1, cell.y)) == -1
	var bottom_open = block_layer.get_cell_source_id(Vector2i(cell.x, cell.y + 1)) == -1
	var left_open = block_layer.get_cell_source_id(Vector2i(cell.x - 1, cell.y)) == -1
	
	var index = 0
	if top_open: index += 1
	if right_open: index += 2
	if bottom_open: index += 4
	if left_open: index += 8
	
	var atlas_x = index % 4
	var atlas_y = index / 4
	
	# Source 9 is the new fog_mask_atlas
	fog_layer.set_cell(cell, 9, Vector2i(atlas_x, atlas_y))"""

content = content.replace(old_dug_section, new_dug_section)

# Update generate_initial_world to run update_fog_mask for all cells at the end
old_gen = """			# Do not set background, let the CanvasModulate handle empty space
			# bg_layer.set_cell(cell, 0, Vector2i(0, 0))
			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			fog_layer.set_cell(cell, 9, Vector2i(0, 0)) # Pure black fog
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)
	
	# Ensure surface is walkable"""

new_gen = """			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)
				
	# Now that all blocks are placed, calculate fog masks
	for x in range(-width / 2, width / 2):
		for y in range(0, depth):
			update_fog_mask(Vector2i(x, y))
	
	# Ensure surface is walkable"""

content = content.replace(old_gen, new_gen)

with open("world.gd", "w") as f:
    f.write(content)

print("Updated world.gd with mask atlas logic")
