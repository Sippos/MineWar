with open("world.gd", "r") as f:
    content = f.read()

# Fix world generation
old_gen = """			bg_layer.set_cell(cell, 0, Vector2i(0, 0))
			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			fog_layer.set_cell(cell, 9, Vector2i(0, 0))"""

new_gen = """			# Do not set background, let the CanvasModulate handle empty space
			# bg_layer.set_cell(cell, 0, Vector2i(0, 0))
			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			fog_layer.set_cell(cell, 9, Vector2i(0, 0)) # Pure black fog"""

content = content.replace(old_gen, new_gen)

# Fix on_cell_dug
old_dug = """	block_layer.erase_cell(cell)
	damage_layer.erase_cell(cell)
	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)"""

new_dug = """	block_layer.erase_cell(cell)
	damage_layer.erase_cell(cell)
	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	bg_layer.erase_cell(cell) # Just in case"""

content = content.replace(old_dug, new_dug)

# Fix update_neighbors
old_edge = """	for n in neighbors:
		var block_id = block_layer.get_cell_source_id(n)
		if block_id != -1:
			# Reveal block by removing fog
			fog_layer.erase_cell(n)
			
			var edge_id = 4
			if block_id == 2:
				edge_id = 5
			elif block_id == 3:
				edge_id = 6
				
			# Add edge overlay
			edge_layer.set_cell(n, edge_id, Vector2i(0, 0))"""

new_edge = """	for n in neighbors:
		var block_id = block_layer.get_cell_source_id(n)
		if block_id != -1:
			# Change fog to the transparent border mask (Source 0)
			# This reveals the edges of the block underneath but keeps the center black
			fog_layer.set_cell(n, 0, Vector2i(0, 0))
			
			# Remove edge overlay as we don't need it anymore
			edge_layer.erase_cell(n)"""

content = content.replace(old_edge, new_edge)

with open("world.gd", "w") as f:
    f.write(content)

print("Updated world.gd logic")
