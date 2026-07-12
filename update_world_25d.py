import re

with open("scripts/systems/world_generation/world.gd", "r") as f:
    content = f.read()

# Add front_layer reference
content = re.sub(
    r'@onready var fog_layer: TileMapLayer = \$MapLayers/FogLayer',
    '@onready var fog_layer: TileMapLayer = $MapLayers/FogLayer\n@onready var front_layer: TileMapLayer = $MapLayers/FrontWallLayer',
    content
)

# Erase front wall when dug
old_erase = """	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	bg_layer.erase_cell(cell)
	
	update_fog_mask(cell)"""

new_erase = """	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	bg_layer.erase_cell(cell)
	front_layer.erase_cell(Vector2i(cell.x, cell.y + 1)) # Erase its own front wall
	
	update_fog_mask(cell)
	update_front_wall(cell)"""

content = content.replace(old_erase, new_erase)

# Add update_front_wall to update_neighbors loop
old_neighbor_loop = """	for n in neighbors:
		update_fog_mask(n)"""

new_neighbor_loop = """	for n in neighbors:
		update_fog_mask(n)
		update_front_wall(n)"""

content = content.replace(old_neighbor_loop, new_neighbor_loop)

# Add update_front_wall function and add it to initialization loop
old_init_loop = """	# Now that all blocks are placed, calculate fog masks
	for x in range(-width / 2, width / 2):
		for y in range(0, depth):
			update_fog_mask(Vector2i(x, y))"""

new_init_loop = """	# Now that all blocks are placed, calculate masks and front walls
	for x in range(-width / 2, width / 2):
		for y in range(0, depth):
			update_fog_mask(Vector2i(x, y))
			update_front_wall(Vector2i(x, y))"""

content = content.replace(old_init_loop, new_init_loop)

# Append update_front_wall definition
front_wall_func = """

func update_front_wall(cell: Vector2i) -> void:
	var block_id = block_layer.get_cell_source_id(cell)
	var below_cell = Vector2i(cell.x, cell.y + 1)
	
	if block_id != -1:
		# If cell is solid, check if below is empty
		if block_layer.get_cell_source_id(below_cell) == -1:
			var front_id = 10 # Easy Front
			if block_id == 2: front_id = 11
			elif block_id == 3: front_id = 12
			
			front_layer.set_cell(below_cell, front_id, Vector2i(0, 0))
		else:
			front_layer.erase_cell(below_cell)
	else:
		# If cell is empty, it can't have a front wall projecting down
		front_layer.erase_cell(below_cell)
"""

content += front_wall_func

with open("scripts/systems/world_generation/world.gd", "w") as f:
    f.write(content)

print("Updated world.gd for 2.5D walls")
