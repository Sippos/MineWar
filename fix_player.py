with open("player.gd", "r") as f:
    content = f.read()

content = content.replace(
    '@onready var tile_map: TileMapLayer = get_node("../TileMapLayer")',
    '@onready var tile_map: TileMapLayer = get_node("../MapLayers/BlockLayer")\n@onready var damage_layer: TileMapLayer = get_node("../MapLayers/DamageLayer")'
)

# Insert damage visual update
old_dig = """				if currently_digging_cell == cell:
					dig_timer += delta
					if dig_timer >= dig_time:"""

new_dig = """				if currently_digging_cell == cell:
					dig_timer += delta
					
					# Show damage overlay if we are halfway done
					if dig_timer > dig_time * 0.5:
						damage_layer.set_cell(cell, 5, Vector2i(0, 0))
					
					if dig_timer >= dig_time:"""

content = content.replace(old_dig, new_dig)

with open("player.gd", "w") as f:
    f.write(content)

print("Updated player.gd")
