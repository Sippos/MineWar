import re

with open("scripts/systems/world_generation/world.gd", "r") as f:
    content = f.read()

# Replace the @onready
content = re.sub(
    r'@onready var tile_map: TileMapLayer = \$TileMapLayer',
    """@onready var bg_layer: TileMapLayer = $MapLayers/BackgroundLayer
@onready var block_layer: TileMapLayer = $MapLayers/BlockLayer
@onready var edge_layer: TileMapLayer = $MapLayers/EdgeLayer
@onready var damage_layer: TileMapLayer = $MapLayers/DamageLayer
@onready var fog_layer: TileMapLayer = $MapLayers/FogLayer""",
    content
)

# Update generate_initial_world
old_gen = """func generate_initial_world() -> void:
	var width = 40
	var depth = 30
	for x in range(-width / 2, width / 2):
		for y in range(0, depth):
			var cell = Vector2i(x, y)
			tile_map.set_cell(cell, 0, Vector2i(0, 0))
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)
	
	# Ensure surface is walkable
	for x in range(-width / 2, width / 2):
		var cell = Vector2i(x, -1)
		if astar.is_in_bounds(cell.x, cell.y):
			astar.set_point_solid(cell, false)
			
	# Small clearing for the base
	for x in range(-2, 3):
		for y in range(0, 2):
			var cell = Vector2i(x, y)
			tile_map.erase_cell(cell)
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, false)"""

new_gen = """func generate_initial_world() -> void:
	var width = 40
	var depth = 30
	for x in range(-width / 2, width / 2):
		for y in range(0, depth):
			var cell = Vector2i(x, y)
			bg_layer.set_cell(cell, 0, Vector2i(0, 0)) # Source 0: bg
			block_layer.set_cell(cell, 1, Vector2i(0, 0)) # Source 1: easy
			fog_layer.set_cell(cell, 6, Vector2i(0, 0)) # Source 6: fog
			if astar.is_in_bounds(cell.x, cell.y):
				astar.set_point_solid(cell, true)
	
	# Ensure surface is walkable
	for x in range(-width / 2, width / 2):
		var cell = Vector2i(x, -1)
		if astar.is_in_bounds(cell.x, cell.y):
			astar.set_point_solid(cell, false)
			
	# Small clearing for the base
	for x in range(-2, 3):
		for y in range(0, 2):
			var cell = Vector2i(x, y)
			if astar.is_in_bounds(cell.x, cell.y):
				on_cell_dug(cell)"""

content = content.replace(old_gen, new_gen)

# Update on_cell_dug
old_dug = """func on_cell_dug(cell: Vector2i) -> void:
	if astar.is_in_bounds(cell.x, cell.y):
		astar.set_point_solid(cell, false)"""

new_dug = """func on_cell_dug(cell: Vector2i) -> void:
	if astar.is_in_bounds(cell.x, cell.y):
		astar.set_point_solid(cell, false)
	
	block_layer.erase_cell(cell)
	damage_layer.erase_cell(cell)
	edge_layer.erase_cell(cell)
	fog_layer.erase_cell(cell)
	
	update_neighbors(cell)

func update_neighbors(cell: Vector2i) -> void:
	var neighbors = [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1)
	]
	
	for n in neighbors:
		if block_layer.get_cell_source_id(n) != -1:
			# Reveal block by removing fog
			fog_layer.erase_cell(n)
			# Add edge overlay
			edge_layer.set_cell(n, 4, Vector2i(0, 0))"""

content = content.replace(old_dug, new_dug)

# Update spawn_wave tile_map.to_global
content = content.replace("tile_map.to_global(tile_map.map_to_local(target_cell))", "block_layer.to_global(block_layer.map_to_local(target_cell))")

with open("scripts/systems/world_generation/world.gd", "w") as f:
    f.write(content)

print("Updated world.gd")
