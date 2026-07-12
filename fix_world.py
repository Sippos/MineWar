with open("scripts/systems/world_generation/world.gd", "r") as f:
    content = f.read()

old_gen = """			bg_layer.set_cell(cell, 0, Vector2i(0, 0)) # Source 0: bg
			block_layer.set_cell(cell, 1, Vector2i(0, 0)) # Source 1: easy
			fog_layer.set_cell(cell, 6, Vector2i(0, 0)) # Source 6: fog"""

new_gen = """			var block_type = 1
			var r = randf()
			if r < 0.2:
				block_type = 3
			elif r < 0.5:
				block_type = 2
				
			bg_layer.set_cell(cell, 0, Vector2i(0, 0))
			block_layer.set_cell(cell, block_type, Vector2i(0, 0))
			fog_layer.set_cell(cell, 9, Vector2i(0, 0))"""

content = content.replace(old_gen, new_gen)

old_edge = """	for n in neighbors:
		if block_layer.get_cell_source_id(n) != -1:
			# Reveal block by removing fog
			fog_layer.erase_cell(n)
			# Add edge overlay
			edge_layer.set_cell(n, 4, Vector2i(0, 0))"""

new_edge = """	for n in neighbors:
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

content = content.replace(old_edge, new_edge)

with open("scripts/systems/world_generation/world.gd", "w") as f:
    f.write(content)

print("Updated world.gd")
